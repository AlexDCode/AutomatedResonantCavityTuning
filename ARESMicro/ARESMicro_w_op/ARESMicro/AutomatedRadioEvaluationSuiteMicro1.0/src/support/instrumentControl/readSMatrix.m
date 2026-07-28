function [freqHz, S, names] = readSMatrix(vna, ports, varargin)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % readSMatrix
    %
    % DESCRIPTION:
    % Trigger one sweep and read the full complex S-parameter matrix for the
    % given ports. This is the "live VNA data" feed for the ARESMicro tuning
    % / optimization loops: it returns exactly the S_params matrix the
    % optiProg scripts operate on, at every sweep frequency.
    %
    %   S(i, j, k) = S_{ports(i), ports(j)} at freqHz(k)
    %              = response at port ports(i) when driving port ports(j)
    %
    % Magnitude in dB is 20*log10(abs(S)); phase in degrees is
    % rad2deg(angle(S)).
    %
    % REQUIREMENTS: every needed Sij trace must already be configured (and
    % the instrument calibrated) on the VNA — for a full 4-port matrix that
    % is 16 traces. Pass 'AutoCreate', true to let the driver define missing
    % traces itself (Keysight dialect, not yet hardware-verified). This
    % function relies on the trace-catalog query, which the Copper Mountain
    % dialect lacks — use it with the Keysight PNA/ENA family; on a CMT808U
    % use readVNATraces instead.
    %
    % INPUT:
    %   vna   - connected VNAInstCtrl (from connectVNA)
    %   ports - vector of port numbers, e.g. 1:4 (default [1 2])
    %
    % Name-Value:
    %   'AutoCreate' - define missing traces on the VNA (default false)
    %
    % OUTPUT:
    %   freqHz - sweep frequencies (Hz), column [npts x 1]
    %   S      - complex [n x n x npts], n = numel(ports), indexed as above
    %   names  - n x n string array of the "Sij" labels, names(i,j)
    %
    % USAGE (inside an optimization step):
    %   [freqHz, S] = readSMatrix(app.VNA, 1:4);
    %   S21dB = squeeze(20*log10(abs(S(2, 1, :))));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if nargin < 2 || isempty(ports), ports = [1 2]; end
    ports = ports(:).';
    if any(ports < 1 | ports > 9 | ports ~= round(ports))
        error("readSMatrix:BadPorts", ...
            "Ports must be integers between 1 and 9 (Sij naming).");
    end

    n = numel(ports);
    names = strings(n, n);
    for i = 1:n
        for j = 1:n
            names(i, j) = "S" + ports(i) + ports(j);
        end
    end

    [freqHz, sMap] = vna.measureComplexByName(names(:), varargin{:});

    npts = numel(freqHz);
    S = complex(zeros(n, n, npts));
    for i = 1:n
        for j = 1:n
            S(i, j, :) = sMap(char(names(i, j)));
        end
    end
end
