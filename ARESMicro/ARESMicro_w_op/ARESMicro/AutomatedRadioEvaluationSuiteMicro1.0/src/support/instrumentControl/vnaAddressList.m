function [items, models, addresses] = vnaAddressList(csvPath)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % vnaAddressList
    %
    % DESCRIPTION:
    % Read the instrument address database and return the VNA entries
    % formatted for a dropdown. Non-VNA instruments (PSUs, signal
    % generators, positioners, ...) are filtered out so the operator cannot
    % connect the wrong kind of instrument to the VNA slot.
    %
    % Both lab CSV schemas are supported:
    %
    %   ARES format (preferred, has an explicit Type column):
    %     Description,Address,Type,Class
    %     Keysight Technologies N5232B,TCPIP0::192.168.1.161::inst0::INSTR,VNA,VNAInstCtrl
    %
    %   ARESMicro legacy format (VNAs recognized by model token):
    %     Manufacturer,Model,Address
    %     Keysight Technologies,N5232B,TCPIP0::192.168.1.161::inst0::INSTR
    %
    % INPUT:
    %   csvPath - (optional) path to instrumentAddresses.csv. When omitted,
    %             the folders above this file are searched (the CSV ships at
    %             the ARESMicro project root).
    %
    % OUTPUT:
    %   items     - cellstr for a dropdown's Items property, 'NA: None' first,
    %               then "Description: Address" entries, sorted.
    %   models    - string array aligned with items ("" for the None entry).
    %               Pass models(k) to connectVNA so the per-model SCPI
    %               dialect (CommandSets/<Model>.json) loads.
    %   addresses - string array aligned with items ("" for the None entry).
    %
    % USAGE (populate the Setup-tab dropdown):
    %   app.VNASliderDropDown.Items = vnaAddressList();
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if nargin < 1 || strlength(string(csvPath)) == 0
        csvPath = findInstrumentCsv_();
    end
    if ~isfile(csvPath)
        error("vnaAddressList:NoDatabase", ...
            "Instrument database not found: %s", csvPath);
    end

    tbl = readtable(csvPath, "TextType", "string", "Delimiter", ",");
    cols = string(tbl.Properties.VariableNames);

    if all(ismember(["Description", "Address"], cols))
        % ARES format. Model = last word of the description (same convention
        % as ARES's InstrumentFactory.splitDescription).
        desc = strtrim(tbl.Description);
        addr = strtrim(tbl.Address);
        mdl  = lastWord_(desc);
        if ismember("Type", cols)
            isVna = strcmpi(strtrim(tbl.Type), "VNA");
        else
            isVna = looksLikeVna_(desc);
        end
    elseif all(ismember(["Manufacturer", "Model", "Address"], cols))
        % ARESMicro legacy format: no Type column, filter by model token.
        mdl  = strtrim(tbl.Model);
        addr = strtrim(tbl.Address);
        desc = strtrim(strtrim(tbl.Manufacturer) + " " + mdl);
        isVna = looksLikeVna_(mdl);
    else
        error("vnaAddressList:BadDatabase", ...
            "%s must have Description,Address[,Type] or Manufacturer,Model,Address columns.", ...
            csvPath);
    end

    keep = strlength(desc) > 0 & strlength(addr) > 0 & isVna;

    [descKeep, order] = sort(desc(keep));
    mdlKeep  = mdl(keep);
    addrKeep = addr(keep);

    items     = [{'NA: None'}; cellstr(descKeep + ": " + addrKeep(order))];
    models    = ["";  mdlKeep(order)];
    addresses = [""; addrKeep(order)];
end

function tf = looksLikeVna_(s)
    % Model-token heuristic for databases without a Type column. Covers the
    % lab's Keysight/Agilent analyzers plus Copper Mountain and R&S families.
    vnaTokens = ["vna", "pna", "ena", "znb", "zva", "e5072", "n5232", ...
                 "cmt", "planar", "s2vna", "s4vna"];
    tf = contains(lower(s), vnaTokens);
end

function w = lastWord_(s)
    % Last whitespace-separated token of each string ("" stays "").
    w = strings(size(s));
    for k = 1:numel(s)
        parts = split(strtrim(s(k)));
        if ~isempty(parts) && strlength(parts(end)) > 0
            w(k) = parts(end);
        end
    end
end

function p = findInstrumentCsv_()
    % Walk up from this file's folder looking for instrumentAddresses.csv
    % (it lives at the ARESMicro project root, above src/).
    here = fileparts(mfilename('fullpath'));
    d = here;
    for k = 1:6
        candidate = fullfile(d, 'instrumentAddresses.csv');
        if isfile(candidate)
            p = candidate;
            return;
        end
        parent = fileparts(d);
        if strcmp(parent, d), break; end
        d = parent;
    end
    % Fall back to a copy next to this file so a packaged/relocated app can
    % ship its own database.
    p = fullfile(here, 'instrumentAddresses.csv');
end
