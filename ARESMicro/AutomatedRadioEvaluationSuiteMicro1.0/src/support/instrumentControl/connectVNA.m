function vna = connectVNA(selection, varargin)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % connectVNA
    %
    % DESCRIPTION:
    % Build, connect, and return the object-oriented VNA driver from either a
    % dropdown selection ("Manufacturer Model: Address") or a raw address
    % string. This is the ARESMicro equivalent of ARES's
    % aresConnectInstrument, trimmed to the VNA-only case.
    %
    % The model token matters: it selects the per-model SCPI dialect
    % CommandSets/<Model>.json (e.g. the Copper Mountain CMT808U speaks a
    % different trace-read syntax than the Keysight defaults). When the model
    % is not supplied it is recovered from the selection text or the
    % instrument CSV; if it stays "auto" the Keysight PNA/ENA defaults apply.
    %
    % INPUT:
    %   selection - dropdown entry "Keysight Technologies N5232B: TCPIP0::..."
    %               or a bare VISA / socket resource string. Pass "SIM" (or
    %               'Simulate', true) for a hardware-free simulated VNA.
    %
    % Name-Value:
    %   'Model'      - model token for the dialect (overrides auto-detect)
    %   'TimeoutSec' - I/O timeout in seconds (default 30, VNAs are slow)
    %   'Simulate'   - true => no hardware, SimTransport underneath
    %
    % OUTPUT:
    %   vna - connected VNAInstCtrl. Typical follow-ups:
    %           meas = readVNATraces(vna);          % everything on screen
    %           [f, S] = readSMatrix(vna, 1:4);     % full 4-port complex data
    %           vna.setContinuous(true);            % live display for operator
    %           vna.disconnect();
    %
    % USAGE (Connect button callback):
    %   app.VNA = connectVNA(app.VNASliderDropDown.Value);
    %   app.VNAStatusLabel.Text = "Connected: " + vna.IDN;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    p = inputParser;
    addParameter(p, 'Model', "", @(x) isstring(x) || ischar(x));
    addParameter(p, 'TimeoutSec', 30, @isnumeric);
    addParameter(p, 'Simulate', false, @islogical);
    parse(p, varargin{:});

    sel = strtrim(string(selection));
    if sel == "" || strcmpi(sel, "NA: None") || endsWith(sel, "None")
        error("connectVNA:NoSelection", ...
            "No VNA selected. Pick an instrument from the dropdown first.");
    end

    % Dropdown entries are "Description: Address". The separator is the
    % first colon-space; the address itself only contains bare "::" pairs.
    selChar = char(sel);
    sepIdx = strfind(selChar, ': ');
    if ~isempty(sepIdx)
        desc    = strtrim(string(selChar(1:sepIdx(1)-1)));
        address = strtrim(string(selChar(sepIdx(1)+2:end)));
    else
        desc    = "";
        address = sel;
    end

    % Resolve the model for the dialect: explicit arg > last word of the
    % description > CSV lookup by address > "auto" (Keysight defaults).
    model = strtrim(string(p.Results.Model));
    if model == "" && desc ~= ""
        words = split(desc);
        model = words(end);
    end
    if model == ""
        model = modelForAddress_(address);
    end
    if model == ""
        model = "auto";
    end

    simulate = p.Results.Simulate || strcmpi(address, "SIM");

    vna = VNAInstCtrl("auto", model, address, ...
        'TimeoutSec', p.Results.TimeoutSec, 'Simulate', simulate);
    vna.connect();
end

function model = modelForAddress_(address)
    % Match the address against the instrument CSV to recover the model.
    model = "";
    try
        [~, models, addresses] = vnaAddressList();
        hit = find(strcmpi(strtrim(addresses), strtrim(address)), 1);
        if ~isempty(hit)
            model = models(hit);
        end
    catch
        % No database is not an error here — the caller falls back to the
        % built-in Keysight dialect.
    end
end
