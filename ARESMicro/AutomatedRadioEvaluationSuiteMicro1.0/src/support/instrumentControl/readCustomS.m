function [freqHz, S, names] = readCustomS(vna, S_params, varargin)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % readCustomS
    %
    % DESCRIPTION:
    % Queries the VNA ONLY for the specific traces listed in S_params.
    % Completely avoids sweeping or retrieving the full matrix.
    %
    % INPUT:
    %   vna      - connected VNAInstCtrl
    %   S_params - string array of specific traces, e.g., ["S11", "S21"]
    %
    % OUTPUT:
    %   freqHz   - sweep frequencies (Hz), column [npts x 1]
    %   S        - complex [m x npts], where m = numel(S_params)
    %   names    - string array matching the order of S
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Clean and force input to a column string array
    names = string(S_params(:));
    m = numel(names);

    % Request ONLY these specific traces from the VNA driver
    % We append 'AutoCreate', true if you want the VNA to build them on the fly
    [freqHz, sMap] = vna.measureComplexByName(names, 'AutoCreate', true);
    npts = numel(freqHz);
    
    % Preallocate the 2D array [number of desired parameters x frequency points]
    S = complex(zeros(m, npts));
    
    % Pull only the requested data out of the returned map
    for idx = 1:m
        paramName = char(names(idx));
        if sMap.isKey(paramName)
            S(idx, :) = sMap(paramName);
        else
            error("readCustomS:MissingTrace", ...
                "Requested trace '%s' was not found or created on the VNA.", paramName);
        end
    end
end