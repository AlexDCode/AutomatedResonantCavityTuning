classdef VNALiveView < handle
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % VNALiveView
    %
    % DESCRIPTION:
    % Continuously updating S-parameter display AND live data source for the
    % ARESMicro Tune tab. A MATLAB timer repeatedly reads the VNA's traces,
    % repaints them onto a UI axes, and keeps the latest frequency /
    % S-parameter arrays available as properties — so the operator watches
    % the S-parameters move while other code (optimizer steps, gap logic,
    % readouts) simply reads the current arrays whenever it wants them.
    %
    % LIVE DATA ACCESS (always the newest completed reads):
    %   app.LiveView.FreqHz   - sweep frequencies (Hz), [npts x 1]
    %   app.LiveView.Data     - [npts x nShown] display-format data (dB, ...)
    %   app.LiveView.SData    - [npts x nShown] complex S-parameters
    %                           (only when 'StoreComplex', true; else [])
    %   app.LiveView.Names    - 1 x nShown trace labels ("S11", ...)
    %   app.LiveView.LastUpdate - datetime of the newest data
    %   m = app.LiveView.latest()  - all of the above in one struct
    %                                (freqHz, data, sdata, names, time)
    %
    % Or push updates into your own variables/UI every tick:
    %   VNALiveView(vna, ax, 'UpdateFcn', @(meas) updateAppVNAData(app, meas))
    %
    % HOW IT STAYS FAST:
    %   - On start() the VNA free-runs (continuous sweep, like its front
    %     panel); each tick only READS trace buffers — no trigger, no
    %     sweep-complete wait.
    %   - Each trace is fetched with a compound select+read SCPI message
    %     (one round trip instead of two; message latency dominates on LAN).
    %   - Only MaxTracesPerTick traces are read per tick, round-robin, so a
    %     16-trace setup never blocks the UI thread for a whole frame —
    %     sliders stay responsive while every trace still refreshes.
    %   - Plot lines are created once and their YData updated in place,
    %     decimated to MaxPoints for App Designer's web renderer.
    %
    % Timer callbacks run on the MATLAB UI thread, so "laggy" almost always
    % means too much I/O per tick: lower MaxTracesPerTick, display fewer
    % traces ('Traces'), or reduce sweep points on the instrument.
    %
    % For a coherent single-sweep complex frame (all Sij from ONE sweep,
    % optimizer-grade) use readSMatrix — but NOT while the live view is
    % polling: both would talk SCPI on the same connection and the
    % interleaved queries corrupt each other. Wrap measurement code with
    % pause()/resume().
    %
    % TYPICAL USAGE (in the app):
    %   app.LiveView = VNALiveView(app.VNA, app.UIAxes, 'Period', 0.1);
    %   app.LiveView.start();
    %   ...
    %   app.LiveView.pause();                 % before optimizer reads
    %   [f, S] = readSMatrix(app.VNA, 1:4);
    %   app.LiveView.resume();
    %   ...
    %   app.LiveView.stop();                  % and in the app's delete()
    %
    %   % 16 traces configured but tuning against a few? Display a subset —
    %   % the biggest speedup available:
    %   app.LiveView = VNALiveView(app.VNA, app.UIAxes, ...
    %       'Traces', ["S11" "S21" "S31" "S41"]);
    %
    % Name-Value (constructor):
    %   'Period'          - seconds between refresh ticks (default 0.1; the
    %                       next tick is scheduled AFTER a read finishes, so
    %                       short periods are always safe)
    %   'Mode'            - "free" (default): sample the free-running sweep.
    %                       "triggered": one full synchronized sweep per
    %                       frame — coherent but slower.
    %   'Traces'          - which traces to display: [] = all (default),
    %                       numeric trace indices (e.g. [1 3 5]), or
    %                       S-parameter names (e.g. ["S11" "S21"]) matched
    %                       against the instrument's trace catalog.
    %   'MaxTracesPerTick'- traces read per tick, round-robin (default 4).
    %   'MaxPoints'       - max plotted points per trace (default 501);
    %                       data is read in full but drawn decimated.
    %   'StoreComplex'    - true: read the underlying complex S-parameters
    %                       (SData filled; Data/plot become 20*log10(|S|),
    %                       regardless of the trace's on-screen format).
    %                       Default false: display-format data only. Free
    %                       mode only.
    %   'UpdateFcn'       - @(meas) callback fired after every tick with the
    %                       latest() struct. Keep it cheap (it runs at the
    %                       tick rate on the UI thread). If it errors it is
    %                       disabled with a single warning.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties (SetAccess = private)
        VNA                              % VNAInstCtrl (not owned; never disconnected here)
        Axes                             % target axes handle
        Period (1,1) double = 0.1        % timer spacing, seconds
        Mode   (1,1) string = "free"     % "free" | "triggered"
        Names  string = strings(1, 0)    % labels of the DISPLAYED traces
        MaxTracesPerTick (1,1) double = 4
        MaxPoints        (1,1) double = 501
        StoreComplex (1,1) logical = false
        UpdateFcn = []                   % @(meas) hook, [] when unset/disabled

        % Live data (read anytime; updated in place by the polling ticks)
        FreqHz double = []               % [npts x 1] sweep frequencies (Hz)
        Data   double = []               % [npts x nShown] display-format data
        SData  = []                      % [npts x nShown] complex (StoreComplex)
        LastUpdate datetime = NaT        % when Data/SData last changed
    end

    properties (Access = private)
        Timer = []                       % timer object, [] when stopped
        Lines = gobjects(1, 0)           % one line per displayed trace
        TraceSel = []                    % requested 'Traces' selection (raw)
        ShowIdx double = []              % instrument trace numbers displayed
        PlotIdx double = []              % decimation indices into the sweep
        Cursor (1,1) double = 0          % round-robin position
        Npts      (1,1) double = 0
        NumTraces (1,1) double = 0       % total traces on the instrument
    end

    methods
        function obj = VNALiveView(vna, ax, varargin)
            % VNALIVEVIEW  Bind a connected VNA to an axes (does not start).
            p = inputParser;
            addParameter(p, 'Period', 0.1, @isnumeric);
            addParameter(p, 'Mode', "free");
            addParameter(p, 'Traces', []);
            addParameter(p, 'MaxTracesPerTick', 4, @isnumeric);
            addParameter(p, 'MaxPoints', 501, @isnumeric);
            addParameter(p, 'StoreComplex', false, @islogical);
            addParameter(p, 'UpdateFcn', []);
            parse(p, varargin{:});

            obj.VNA    = vna;
            obj.Axes   = ax;
            % Timer periods have millisecond resolution; keep a sane floor.
            obj.Period = max(0.02, round(p.Results.Period * 1000) / 1000);
            obj.Mode   = lower(string(p.Results.Mode));
            if ~ismember(obj.Mode, ["free", "triggered"])
                error("VNALiveView:BadMode", ...
                    "Mode must be ""free"" or ""triggered"".");
            end
            obj.TraceSel         = p.Results.Traces;
            obj.MaxTracesPerTick = max(1, round(p.Results.MaxTracesPerTick));
            obj.MaxPoints        = max(2, round(p.Results.MaxPoints));
            obj.StoreComplex     = p.Results.StoreComplex;
            obj.UpdateFcn        = p.Results.UpdateFcn;
            if obj.StoreComplex && obj.Mode == "triggered"
                error("VNALiveView:ComplexTriggered", ...
                    "'StoreComplex' needs Mode ""free"". For coherent " + ...
                    "single-sweep complex frames use readSMatrix instead.");
            end
            if ~isempty(obj.UpdateFcn) && ~isa(obj.UpdateFcn, 'function_handle')
                error("VNALiveView:BadUpdateFcn", ...
                    "'UpdateFcn' must be a function handle @(meas) ...");
            end
        end

        function start(obj)
            % START  Prime the display (one synchronized sweep to learn the
            % trace setup), then begin polling.
            if obj.isRunning(), return; end
            obj.prime_();
            if isempty(obj.Timer) || ~isvalid(obj.Timer)
                % fixedSpacing waits Period AFTER each refresh finishes, so a
                % slow instrument can never make ticks pile up.
                obj.Timer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period',        obj.Period, ...
                    'Name',          'ARESMicro-VNA-LiveView', ...
                    'TimerFcn',      @(~, ~) obj.tickSafe_());
            end
            start(obj.Timer);
        end

        function stop(obj)
            % STOP  Stop polling and release the timer. The last frame stays
            % on the axes (and in FreqHz/Data/SData); the VNA keeps sweeping
            % for its own display.
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end
            obj.Timer = [];
        end

        function pause(obj)
            % PAUSE  Suspend polling but keep the timer and plot lines, so
            % other code (readSMatrix, readVNATraces) can own the instrument.
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
            end
        end

        function resume(obj)
            % RESUME  Continue polling after pause(). Restores free-running
            % sweep first — measurement code leaves the VNA in hold.
            if isempty(obj.Timer) || ~isvalid(obj.Timer)
                obj.start();
                return;
            end
            if obj.Mode == "free"
                obj.VNA.setContinuous(true);
            end
            if ~obj.isRunning()
                start(obj.Timer);
            end
        end

        function tf = isRunning(obj)
            tf = ~isempty(obj.Timer) && isvalid(obj.Timer) && ...
                 strcmp(obj.Timer.Running, 'on');
        end

        function meas = latest(obj)
            % LATEST  Snapshot of the newest live data in one call.
            %
            % OUTPUT struct fields:
            %   .freqHz - [npts x 1] Hz          .data  - [npts x nShown]
            %   .sdata  - complex or []          .names - 1 x nShown labels
            %   .time   - datetime of the newest data (NaT before priming)
            meas.freqHz = obj.FreqHz;
            meas.data   = obj.Data;
            meas.sdata  = obj.SData;
            meas.names  = obj.Names;
            meas.time   = obj.LastUpdate;
        end

        function refresh(obj)
            % REFRESH  One polling step: read the next MaxTracesPerTick
            % traces (round-robin), store their data, and repaint their
            % lines. The timer calls this; call it directly for on-demand
            % updates.
            if obj.NumTraces < 1 || isempty(obj.Lines) || ~all(isgraphics(obj.Lines))
                obj.prime_();   % never primed, or someone cleared the axes
                return;
            end

            nShow = numel(obj.Lines);
            if obj.Mode == "triggered"
                meas = readVNATraces(obj.VNA);
                if numel(meas.freqHz) ~= obj.Npts || size(meas.data, 2) ~= obj.NumTraces
                    obj.prime_();   % sweep setup changed on the instrument
                    return;
                end
                obj.Data = meas.data(:, obj.ShowIdx);
                for k = 1:nShow
                    set(obj.Lines(k), 'YData', obj.Data(obj.PlotIdx, k));
                end
            else
                chunk = min(obj.MaxTracesPerTick, nShow);
                for c = 1:chunk
                    obj.Cursor = mod(obj.Cursor, nShow) + 1;
                    k = obj.Cursor;
                    if obj.StoreComplex
                        s = obj.readComplexAt_(obj.ShowIdx(k));
                        if isempty(s)
                            obj.prime_();   % sweep setup changed
                            return;
                        end
                        obj.SData(:, k) = s;
                        d = 20 * log10(abs(s));
                    else
                        d = obj.readTraceAt_(obj.ShowIdx(k));
                        if isempty(d)
                            obj.prime_();   % sweep setup changed
                            return;
                        end
                    end
                    obj.Data(:, k) = d;
                    set(obj.Lines(k), 'YData', d(obj.PlotIdx));
                end
            end
            obj.LastUpdate = datetime('now');
            drawnow limitrate;
            obj.fireUpdate_();
        end

        function delete(obj)
            try obj.stop(); catch, end
        end
    end

    methods (Access = private)
        function prime_(obj)
            % One synchronized sweep to learn point count, trace count, and
            % names; build the plot lines once; then free-run if configured.
            meas = readVNATraces(obj.VNA);
            obj.Npts      = numel(meas.freqHz);
            obj.NumTraces = size(meas.data, 2);
            obj.ShowIdx   = obj.resolveTraces_(meas.names);
            obj.Names     = meas.names(obj.ShowIdx);

            % Seed the live data with the primed frame. SData starts as NaN
            % and fills as the round-robin visits each trace (one full cycle
            % = nShown/MaxTracesPerTick ticks).
            obj.FreqHz = meas.freqHz;
            obj.Data   = meas.data(:, obj.ShowIdx);
            if obj.StoreComplex
                obj.SData = complex(nan(obj.Npts, numel(obj.ShowIdx)));
            else
                obj.SData = [];
            end
            obj.LastUpdate = datetime('now');

            % Decimate what is DRAWN (not what is read): App Designer axes
            % render in a web canvas, and 16 x 1601-point lines per frame is
            % renderer lag, not instrument lag.
            if obj.Npts > obj.MaxPoints
                obj.PlotIdx = unique(round(linspace(1, obj.Npts, obj.MaxPoints)));
            else
                obj.PlotIdx = 1:obj.Npts;
            end
            fGHz = obj.FreqHz(obj.PlotIdx) / 1e9;

            ax = obj.Axes;
            cla(ax);
            obj.Lines = gobjects(1, numel(obj.ShowIdx));
            hold(ax, 'on');
            for k = 1:numel(obj.ShowIdx)
                obj.Lines(k) = plot(ax, fGHz, ...
                    obj.Data(obj.PlotIdx, k), 'LineWidth', 1.2);
            end
            hold(ax, 'off');
            grid(ax, 'on');
            xlabel(ax, 'Frequency (GHz)');
            ylabel(ax, 'Magnitude (dB)');
            title(ax, 'S-Parameters (live)');
            legend(ax, obj.Names, 'Location', 'southeast');
            % X never changes between sweeps; freezing it skips a per-frame
            % autoscale pass.
            ax.XLim = [fGHz(1), fGHz(end)];

            obj.Cursor = 0;
            if obj.Mode == "free"
                obj.VNA.setContinuous(true);
            end
        end

        function idx = resolveTraces_(obj, names)
            % Map the 'Traces' option onto instrument trace numbers.
            sel = obj.TraceSel;
            if isempty(sel)
                idx = 1:obj.NumTraces;
                return;
            end
            if isnumeric(sel)
                idx = round(sel(:).');
                if any(idx < 1 | idx > obj.NumTraces)
                    error("VNALiveView:BadTraceIndex", ...
                        "'Traces' indices must be between 1 and %d.", obj.NumTraces);
                end
                return;
            end
            want = string(sel);
            want = want(:).';
            idx = zeros(1, numel(want));
            for k = 1:numel(want)
                hit = find(strcmpi(names, want(k)), 1);
                if isempty(hit)
                    error("VNALiveView:UnknownTrace", ...
                        "No trace measures %s. Configured: %s", ...
                        want(k), strjoin(names, ", "));
                end
                idx(k) = hit;
            end
        end

        function d = readTraceAt_(obj, traceNum)
            % Read one trace's formatted data, compound fast path when the
            % driver has it. Returns [] when the size no longer matches the
            % primed sweep (caller re-primes).
            vna = obj.VNA;
            if ismethod(vna, 'readFormattedTraceAt')
                d = vna.readFormattedTraceAt(traceNum);
            else
                vna.selectTrace(traceNum);
                d = vna.readFormattedTrace();
            end
            d = d(:);
            if numel(d) == 2 * obj.Npts
                d = d(1:2:end);   % Copper Mountain (value, 0) pairs
            end
            if numel(d) ~= obj.Npts
                d = [];
            end
        end

        function c = readComplexAt_(obj, traceNum)
            % Read one trace's complex S-parameter data, compound fast path
            % when the driver has it. Returns [] on a size mismatch.
            vna = obj.VNA;
            if ismethod(vna, 'readComplexTraceAt')
                c = vna.readComplexTraceAt(traceNum);
            else
                vna.selectTrace(traceNum);
                c = vna.readComplexTrace();
            end
            c = c(:);
            if numel(c) ~= obj.Npts
                c = [];
            end
        end

        function fireUpdate_(obj)
            % Push the latest data to the user hook; a broken hook must not
            % kill (or spam) the poller, so it is disabled on first error.
            if isempty(obj.UpdateFcn), return; end
            try
                obj.UpdateFcn(obj.latest());
            catch ME
                obj.UpdateFcn = [];
                warning("VNALiveView:UpdateFcnDisabled", ...
                    "UpdateFcn errored and was disabled: %s", ME.message);
            end
        end

        function tickSafe_(obj)
            % Timer callback: a dead instrument must stop the poller with a
            % warning, never spray an error dialog per tick.
            try
                obj.refresh();
            catch ME
                obj.stop();
                warning("VNALiveView:Stopped", ...
                    "Live S-parameter view stopped: %s", ME.message);
            end
        end
    end
end
