function test_vna_sim
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % test_vna_sim
    %
    % Headless smoke test for the ARESMicro VNA integration. Runs entirely
    % against SimTransport — no hardware, no VISA — and exercises:
    %   1. vnaAddressList  : CSV parsing + VNA-only filtering
    %   2. connectVNA      : dropdown-entry parsing + simulated connect
    %   3. readVNATraces   : 16-trace 4-port read (Keysight dialect)
    %   4. readSMatrix     : full 4x4 complex matrix assembly
    %   5. CMT808U dialect : command override + (value,0) de-interleaving
    %   6. plotVNATraces   : renders onto an invisible axes
    %
    % Run from MATLAB:
    %   cd .../src/support/instrumentControl/tests; test_vna_sim
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    here = fileparts(mfilename('fullpath'));
    addpath(fileparts(here));   % instrumentControl folder

    total = 0; failed = 0;

    %% 1. vnaAddressList filters the ARESMicro CSV to VNAs only
    [ok, msg] = runCheck_(@checkAddressList_);
    [total, failed] = tally_(total, failed, ok, msg, "vnaAddressList");

    %% 2. connectVNA parses a dropdown entry and connects in simulation
    [ok, msg] = runCheck_(@checkConnect_);
    [total, failed] = tally_(total, failed, ok, msg, "connectVNA (sim)");

    %% 3+4. Keysight 4-port: readVNATraces and readSMatrix
    [ok, msg] = runCheck_(@checkKeysight4Port_);
    [total, failed] = tally_(total, failed, ok, msg, "4-port read (Keysight sim)");

    %% 5. Copper Mountain dialect + formatted-data de-interleave
    [ok, msg] = runCheck_(@checkCmtDialect_);
    [total, failed] = tally_(total, failed, ok, msg, "CMT808U dialect (sim)");

    %% 6. plotVNATraces draws one line per trace
    [ok, msg] = runCheck_(@checkPlot_);
    [total, failed] = tally_(total, failed, ok, msg, "plotVNATraces");

    %% 7. VNALiveView: timer lifecycle + in-place live updates
    [ok, msg] = runCheck_(@checkLiveView_);
    [total, failed] = tally_(total, failed, ok, msg, "VNALiveView (sim)");

    %% 8. VNALiveView performance paths: chunking, subset, decimation
    [ok, msg] = runCheck_(@checkLiveViewPerf_);
    [total, failed] = tally_(total, failed, ok, msg, "VNALiveView chunking/subset (sim)");

    %% 9. Live data properties, StoreComplex, latest(), UpdateFcn
    [ok, msg] = runCheck_(@checkLiveData_);
    [total, failed] = tally_(total, failed, ok, msg, "VNALiveView live data (sim)");

    %% 10. disconnectVNA: full teardown, never throws
    [ok, msg] = runCheck_(@checkDisconnect_);
    [total, failed] = tally_(total, failed, ok, msg, "disconnectVNA (sim)");

    fprintf("\n%d/%d checks passed.\n", total - failed, total);
    if failed > 0
        error("test_vna_sim:Failed", "%d check(s) failed.", failed);
    end
end

%% ---------------------------------------------------------------- checks
function checkAddressList_()
    % Must hold for BOTH supported CSV schemas (ARES Description/Type format
    % and the ARESMicro legacy Manufacturer,Model,Address format).
    [items, models, addresses] = vnaAddressList();
    assert(strcmp(items{1}, 'NA: None'), "first item must be 'NA: None'");
    assert(numel(items) == numel(models) && numel(models) == numel(addresses), ...
        "outputs must be aligned");
    joined = string(items(:));
    assert(any(contains(joined, "N5232B")), "N5232B missing from VNA list");
    assert(any(contains(joined, "E5072A")), "E5072A missing from VNA list");
    assert(~any(contains(joined, "EMCenter")), "non-VNA EMCenter leaked in");
    assert(~any(contains(joined, "E36233A")), "non-VNA PSU leaked in");
    assert(~any(contains(joined, "SMW200A")), "non-VNA generator leaked in");

    % The model token must line up with its item (it selects the dialect).
    hit = find(contains(joined, "N5232B"), 1);
    assert(models(hit) == "N5232B", "model column misaligned with items");
    assert(startsWith(joined(hit), models(hit)) || contains(joined(hit), models(hit)), ...
        "item text should contain its model");
    assert(contains(joined(hit), addresses(hit)), ...
        "item text should contain its address");
end

function checkConnect_()
    vna = connectVNA( ...
        "Keysight Technologies N5232B: TCPIP0::192.168.1.161::inst0::INSTR", ...
        'Simulate', true);
    cleanup = onCleanup(@() vna.disconnect());
    assert(vna.IsConnected, "simulated VNA did not connect");
    assert(vna.Address == "TCPIP0::192.168.1.161::inst0::INSTR", ...
        "address was not parsed out of the dropdown entry");
    assert(strlength(vna.IDN) > 0, "no IDN after connect");

    % 'NA: None' must be rejected with a clear error, not a crash later.
    threw = false;
    try
        connectVNA("NA: None");
    catch ME
        threw = strcmp(ME.identifier, "connectVNA:NoSelection");
    end
    assert(threw, "'NA: None' selection was not rejected");
end

function checkKeysight4Port_()
    npts = 11;
    t = makeSimVna_("Keysight Technologies,N5232B,SIM,1.0", npts, false);
    t.setResponse('CALC1:PAR:COUN?', '16');
    t.setResponse('CALC1:PAR:CAT:EXT?', catalog16_());

    vna = VNAInstCtrl("auto", "N5232B", "SIM-INJECTED", "Transport", t);
    vna.connect();
    cleanup = onCleanup(@() vna.disconnect());

    % readVNATraces: trace k is a constant k, names come from the catalog.
    meas = readVNATraces(vna);
    assert(isequal(size(meas.data), [npts 16]), "wrong trace matrix size");
    assert(meas.names(1) == "S11" && meas.names(16) == "S44", ...
        "catalog names not parsed");
    assert(all(meas.data(:, 5) == 5), "trace 5 data wrong");
    assert(numel(meas.freqHz) == npts && meas.freqHz(1) == 1e9, ...
        "frequency axis wrong");

    % readSMatrix: catalog position k serves complex k - 1i*k, so
    % S(i,j,:) must equal k = (i-1)*4 + j.
    [freqHz, S, names] = readSMatrix(vna, 1:4);
    assert(isequal(size(S), [4 4 npts]), "wrong S-matrix size");
    assert(numel(freqHz) == npts, "wrong freq length");
    assert(names(2, 1) == "S21", "name grid wrong");
    for i = 1:4
        for j = 1:4
            k = (i-1)*4 + j;
            assert(all(squeeze(S(i, j, :)) == k - 1i*k), ...
                "S(%d,%d) has wrong complex data", i, j);
        end
    end
end

function checkCmtDialect_()
    npts = 11;
    t = makeSimVna_("CMT,CMT808U,SIM,1.0", npts, true);   % (value,0) pairs
    t.setResponse('CALC1:PAR:COUN?', '2');

    vna = VNAInstCtrl("auto", "CMT808U", "SIM-INJECTED", "Transport", t);
    vna.connect();
    cleanup = onCleanup(@() vna.disconnect());

    meas = readVNATraces(vna);

    % The CMT JSON dialect must have overridden the Keysight defaults.
    assert(any(contains(t.CommandLog, "TRIG:SING")), ...
        "CMT sweep command not used - dialect did not load");
    assert(any(contains(t.CommandLog, "CALC1:DATA:FDAT?")), ...
        "CMT trace-read command not used - dialect did not load");

    % De-interleaved (value,0) pairs and generic fallback names.
    assert(isequal(size(meas.data), [npts 2]), "CMT data not de-interleaved");
    assert(all(meas.data(:, 2) == 2), "CMT trace values wrong after de-interleave");
    assert(meas.names(1) == "Trace 1", "expected generic fallback trace names");
end

function checkPlot_()
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));
    ax = axes(fig);

    meas.freqHz = linspace(1e9, 3e9, 21).';
    meas.data   = [zeros(21, 1), -10*ones(21, 1), -20*ones(21, 1)];
    meas.names  = ["S11" "S21" "S22"];
    plotVNATraces(ax, meas);

    lines = findobj(ax, 'Type', 'Line');
    assert(numel(lines) == 3, "expected one line per trace");
end

function checkLiveView_()
    npts = 11;
    t = makeSimVna_("Keysight Technologies,N5232B,SIM,1.0", npts, false);
    t.setResponse('CALC1:PAR:COUN?', '2');
    t.setResponse('CALC1:PAR:CAT:EXT?', 'CH1_S11_1,S11,CH1_S21_2,S21');

    vna = VNAInstCtrl("auto", "N5232B", "SIM-INJECTED", "Transport", t);
    vna.connect();
    cleanupVna = onCleanup(@() vna.disconnect());

    fig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() close(fig));
    ax = axes(fig);

    live = VNALiveView(vna, ax, 'Period', 0.05);
    cleanupLive = onCleanup(@() delete(live));

    live.start();
    assert(live.isRunning(), "timer did not start");
    assert(live.Names(2) == "S21", "live view did not learn trace names");
    lines = findobj(ax, 'Type', 'Line');
    assert(numel(lines) == 2, "expected one live line per trace");
    assert(any(contains(t.CommandLog, "SENS1:SWE:MODE CONT")), ...
        "free mode must put the VNA in continuous sweep");
    assert(any(contains(t.CommandLog, "CALC1:PAR:MNUM 1;:CALC1:DATA? FDATA")), ...
        "compound select+read fast path not used");

    % New instrument data must land on the existing lines after a refresh.
    t.BinaryFcn = @(cmd, type) -7 * ones(1, npts);
    live.refresh();
    lines = findobj(ax, 'Type', 'Line');
    assert(all(lines(1).YData == -7) && all(lines(2).YData == -7), ...
        "refresh did not update line data in place");

    % pause suspends polling (instrument free for readSMatrix), resume restarts.
    live.pause();
    assert(~live.isRunning(), "pause did not stop the timer");
    live.resume();
    assert(live.isRunning(), "resume did not restart the timer");

    live.stop();
    assert(~live.isRunning(), "stop did not stop the timer");
end

function checkLiveViewPerf_()
    npts = 11;

    % --- Round-robin chunking: 16 traces, 4 per tick -> 4 ticks per frame.
    t = makeSimVna_("Keysight Technologies,N5232B,SIM,1.0", npts, false);
    t.setResponse('CALC1:PAR:COUN?', '16');
    t.setResponse('CALC1:PAR:CAT:EXT?', catalog16_());
    vna = VNAInstCtrl("auto", "N5232B", "SIM-INJECTED", "Transport", t);
    vna.connect();
    cleanupVna = onCleanup(@() vna.disconnect());

    fig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() close(fig));
    ax = axes(fig);

    live = VNALiveView(vna, ax, 'MaxTracesPerTick', 4);
    cleanupLive = onCleanup(@() delete(live));
    live.refresh();                        % primes: 16 lines, values 1..16
    lines = findobj(ax, 'Type', 'Line');
    assert(numel(lines) == 16, "expected 16 primed lines");

    t.BinaryFcn = @(cmd, type) -7 * ones(1, npts);
    nUpdated = @() sum(arrayfun(@(L) all(L.YData == -7), findobj(ax, 'Type', 'Line')));
    live.refresh();
    assert(nUpdated() == 4, "one tick must update exactly MaxTracesPerTick traces");
    live.refresh(); live.refresh(); live.refresh();
    assert(nUpdated() == 16, "four ticks must complete the 16-trace frame");

    % --- Subset by name + display decimation on a fresh sim.
    t2 = makeSimVna_("Keysight Technologies,N5232B,SIM,1.0", npts, false);
    t2.setResponse('CALC1:PAR:COUN?', '16');
    t2.setResponse('CALC1:PAR:CAT:EXT?', catalog16_());
    vna2 = VNAInstCtrl("auto", "N5232B", "SIM-INJECTED", "Transport", t2);
    vna2.connect();
    cleanupVna2 = onCleanup(@() vna2.disconnect());
    ax2 = axes(figure('Visible', 'off'));
    cleanupFig2 = onCleanup(@() close(ax2.Parent));

    live2 = VNALiveView(vna2, ax2, 'Traces', ["S21" "S11"], 'MaxPoints', 5);
    cleanupLive2 = onCleanup(@() delete(live2));
    live2.refresh();
    assert(isequal(live2.Names, ["S21" "S11"]), "subset names wrong");
    lines2 = findobj(ax2, 'Type', 'Line');
    assert(numel(lines2) == 2, "subset must plot only the requested traces");
    assert(numel(lines2(1).XData) == 5, "MaxPoints decimation not applied");
    % S21 is catalog trace 5, S11 is trace 1 -> one line all 5s, one all 1s.
    vals = sort(arrayfun(@(L) L.YData(1), lines2));
    assert(isequal(vals(:).', [1 5]), "subset mapped to wrong instrument traces");

    % Unknown name must fail loudly, listing what exists.
    threw = false;
    try
        bad = VNALiveView(vna2, ax2, 'Traces', "S99");
        bad.refresh();
    catch ME
        threw = strcmp(ME.identifier, "VNALiveView:UnknownTrace");
    end
    assert(threw, "unknown trace name was not rejected");
end

function checkLiveData_()
    npts = 11;
    t = makeSimVna_("Keysight Technologies,N5232B,SIM,1.0", npts, false);
    t.setResponse('CALC1:PAR:COUN?', '2');
    t.setResponse('CALC1:PAR:CAT:EXT?', 'CH1_S11_1,S11,CH1_S21_2,S21');
    vna = VNAInstCtrl("auto", "N5232B", "SIM-INJECTED", "Transport", t);
    vna.connect();
    cleanupVna = onCleanup(@() vna.disconnect());
    fig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() close(fig));
    ax = axes(fig);

    % --- Default (formatted) mode: arrays populate and stay in sync.
    live = VNALiveView(vna, ax);
    cleanupLive = onCleanup(@() delete(live));
    live.refresh();                        % prime
    live.refresh();                        % first chunk (both traces)
    m = live.latest();
    assert(isequal(size(m.data), [npts 2]) && numel(m.freqHz) == npts, ...
        "latest() arrays have wrong size");
    assert(all(m.data(:, 2) == 2), "Data column mismatched to trace");
    assert(isempty(m.sdata), "sdata must be empty without StoreComplex");
    assert(~isnat(m.time), "LastUpdate not stamped");
    assert(isequal(m.names, ["S11" "S21"]), "names wrong in latest()");

    % --- StoreComplex + UpdateFcn: complex arrays and per-tick push.
    live2 = VNALiveView(vna, ax, 'StoreComplex', true, ...
        'UpdateFcn', @(meas) updateSink_('put', meas));
    cleanupLive2 = onCleanup(@() delete(live2));
    live2.refresh();                       % prime (SData still NaN)
    live2.refresh();                       % complex chunk fills both traces
    assert(all(live2.SData(:, 2) == 2 - 2i), "complex trace data wrong");
    assert(abs(live2.Data(1, 2) - 20*log10(abs(2 - 2i))) < 1e-12, ...
        "displayed dB must be 20*log10(|S|) in complex mode");
    assert(any(contains(t.CommandLog, "CALC1:PAR:MNUM 2;:CALC1:DATA? SDATA")), ...
        "compound complex read not used");
    pushed = updateSink_('get');
    assert(isstruct(pushed) && all(pushed.sdata(:, 1) == 1 - 1i), ...
        "UpdateFcn did not receive the latest data");

    % StoreComplex is a free-run feature; triggered mode must be rejected.
    threw = false;
    try
        VNALiveView(vna, ax, 'StoreComplex', true, 'Mode', "triggered");
    catch ME
        threw = strcmp(ME.identifier, "VNALiveView:ComplexTriggered");
    end
    assert(threw, "StoreComplex+triggered was not rejected");

    % --- A broken UpdateFcn is disabled (once) instead of killing polling.
    live3 = VNALiveView(vna, ax, 'UpdateFcn', @(meas) error("boom"));
    cleanupLive3 = onCleanup(@() delete(live3));
    live3.refresh();                       % prime
    live3.refresh();                       % fires hook -> warns + disables
    assert(isempty(live3.UpdateFcn), "broken UpdateFcn was not disabled");
    live3.refresh();                       % must keep polling without error
end

function out = updateSink_(mode, meas)
    % Capture bin for the UpdateFcn test ('put' stores, 'get' returns).
    persistent LAST
    if mode == "put"
        LAST = meas;
        out = [];
    else
        out = LAST;
    end
end

function checkDisconnect_()
    % Empty / never-connected inputs: must be silent no-ops.
    disconnectVNA([], []);
    disconnectVNA([]);

    npts = 11;
    t = makeSimVna_("Keysight Technologies,N5232B,SIM,1.0", npts, false);
    t.setResponse('CALC1:PAR:COUN?', '2');
    t.setResponse('CALC1:PAR:CAT:EXT?', 'CH1_S11_1,S11,CH1_S21_2,S21');
    vna = VNAInstCtrl("auto", "N5232B", "SIM-INJECTED", "Transport", t);
    vna.connect();

    fig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() close(fig));
    ax = axes(fig);
    live = VNALiveView(vna, ax);
    live.start();
    assert(live.isRunning() && vna.IsConnected, "test setup failed");

    disconnectVNA(vna, live);
    assert(~live.isRunning(), "disconnectVNA must stop the live view timer");
    assert(~vna.IsConnected, "disconnectVNA must close the connection");
    assert(any(contains(t.CommandLog, "SENS1:SWE:MODE CONT")), ...
        "disconnectVNA should hand back a free-running display");

    % Second call on already-torn-down objects: still silent.
    disconnectVNA(vna, live);
end

%% ----------------------------------------------------------- sim plumbing
function s = catalog16_()
    % Trace catalog for a full 4-port setup: trace k measures Sij with
    % i = ceil(k/4), j = mod(k-1,4)+1 (row-wise S11, S12, ..., S44).
    catalog = strings(1, 16);
    for k = 1:16
        i = ceil(k/4); j = mod(k-1, 4) + 1;
        catalog(k) = sprintf('CH1_S%d%d_%d,S%d%d', i, j, k, i, j);
    end
    s = char(strjoin(catalog, ","));
end

function t = makeSimVna_(idn, npts, cmtPairs)
    % SimTransport that behaves like a swept VNA: the frequency axis is a
    % linspace, and each trace returns constant data equal to its trace
    % number (found from the most recent select-trace command in the log).
    % cmtPairs = true emits formatted data as (value, 0) pairs like a
    % Copper Mountain analyzer.
    t = SimTransport("IdnString", idn);
    t.BinaryFcn = @(cmd, type) simBinary_(t, cmd, npts, cmtPairs);
end

function d = simBinary_(t, cmd, npts, cmtPairs)
    u = upper(string(cmd));
    if contains(u, "X:VAL") || contains(u, "FREQ:DATA")
        d = linspace(1e9, 3e9, npts);
        return;
    end
    k = lastSelectedTrace_(t);
    if contains(u, "SDAT")
        % Complex data: re/im interleaved, re = k, im = -k.
        d = reshape([k*ones(1, npts); -k*ones(1, npts)], 1, []);
    elseif cmtPairs
        % CMT formatted data: (value, 0) pairs.
        d = reshape([k*ones(1, npts); zeros(1, npts)], 1, []);
    else
        d = k * ones(1, npts);
    end
end

function k = lastSelectedTrace_(t)
    % Recover the trace index from the newest select-trace command in the
    % log; understands both dialects (Keysight MNUM and CMT PARn:SEL).
    k = 1;
    log = t.CommandLog;
    for idx = numel(log):-1:1
        tok = regexp(log(idx), "CALC1:PAR:MNUM\s+(\d+)", "tokens", "once");
        if isempty(tok)
            tok = regexp(log(idx), "CALC1:PAR(\d+):SEL", "tokens", "once");
        end
        if ~isempty(tok)
            k = str2double(tok{1});
            return;
        end
    end
end

%% ------------------------------------------------------------- harness
function [ok, msg] = runCheck_(fcn)
    try
        fcn();
        ok = true; msg = "";
    catch ME
        ok = false; msg = string(ME.message);
    end
end

function [total, failed] = tally_(total, failed, ok, msg, name)
    total = total + 1;
    if ok
        fprintf("PASS  %s\n", name);
    else
        failed = failed + 1;
        fprintf(2, "FAIL  %s: %s\n", name, msg);
    end
end
