function meas = readVNATraces(vna, varargin)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % readVNATraces
    %
    % DESCRIPTION:
    % Trigger one sweep and read EVERY measurement trace currently configured
    % on the VNA, whatever it shows (S11 return loss, S21 through, isolation
    % terms, ...). The operator sets up traces and CALIBRATES on the
    % instrument; this function only reads — it never changes the setup.
    %
    % Each trace comes back in whatever display format it has on the VNA
    % (dB log magnitude, phase, VSWR, ...). For raw complex S-parameters use
    % readSMatrix instead.
    %
    % Unlike VNAInstCtrl.measureAllTraces, this loop de-interleaves the
    % (value, 0) pair format that Copper Mountain analyzers return for
    % formatted data (CALC:DATA:FDAT?), so it works on both the Keysight
    % PNA/ENA family and a CMT808U behind the S4 socket server.
    %
    % INPUT:
    %   vna - connected VNAInstCtrl (from connectVNA)
    %
    % Name-Value:
    %   'RestoreContinuous' - restore free-running sweeps after the read so
    %                         the operator sees a live display (default
    %                         false; leave it off inside optimization loops,
    %                         it costs a sweep-state round trip per call)
    %
    % OUTPUT:
    %   meas - struct with fields:
    %            .freqHz - sweep frequencies (Hz), column [npts x 1]
    %            .data   - [npts x nTraces] formatted data, one column/trace
    %            .names  - 1 x nTraces string array of S-parameter labels
    %                      ("Trace k" fallback when the instrument cannot
    %                      report a catalog, e.g. Copper Mountain)
    %
    % USAGE (Measure button callback):
    %   meas = readVNATraces(app.VNA);
    %   plotVNATraces(app.UIAxes, meas);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    p = inputParser;
    addParameter(p, 'RestoreContinuous', false, @islogical);
    parse(p, varargin{:});

    vna.flush();
    vna.scpi('cls');
    vna.configureBinaryTransfer();
    vna.triggerSingleSweep();

    nTraces = round(str2double(vna.scpi('trace_count?')));
    if ~isfinite(nTraces) || nTraces < 1
        error("readVNATraces:NoTraces", ...
            "No measurement traces are configured on the VNA.");
    end

    freqHz = vna.getFrequencyAxis();
    freqHz = freqHz(:);
    npts   = numel(freqHz);
    data   = zeros(npts, nTraces);

    useCompound = ismethod(vna, 'readFormattedTraceAt');
    for i = 1:nTraces
        if useCompound
            % One round trip per trace (select+read in a single message).
            d = vna.readFormattedTraceAt(i);
        else
            vna.selectTrace(i);
            d = vna.readFormattedTrace();
        end
        d = d(:);
        if numel(d) == 2 * npts
            % Copper Mountain formatted data arrives as (value, 0) pairs.
            d = d(1:2:end);
        elseif numel(d) ~= npts
            error("readVNATraces:SizeMismatch", ...
                "Trace %d returned %d points but the frequency axis has %d.", ...
                i, numel(d), npts);
        end
        data(:, i) = d;
    end

    meas.freqHz = freqHz;
    meas.data   = data;
    meas.names  = catalogNames_(vna, nTraces);

    if p.Results.RestoreContinuous
        vna.setContinuous(true);
    end
end

function names = catalogNames_(vna, n)
    % S-parameter labels from the trace catalog ("name1,Sxy,name2,Sxy,...").
    % Instruments without the catalog query (Copper Mountain) get generic
    % fallback names rather than an error.
    names = "Trace " + string(1:n);
    try
        raw = strtrim(vna.scpi('trace_catalog?'));
        raw = erase(raw, '"');
        parts  = strtrim(split(raw, ","));
        params = parts(2:2:end);
        for k = 1:min(n, numel(params))
            if strlength(params(k)) > 0
                names(k) = params(k);
            end
        end
    catch
        % keep the generic fallback names
    end
end
