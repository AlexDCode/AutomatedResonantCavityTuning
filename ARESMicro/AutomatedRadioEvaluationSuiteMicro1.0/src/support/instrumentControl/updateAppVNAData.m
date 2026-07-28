function updateAppVNAData(app, meas)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % updateAppVNAData
    %
    % DESCRIPTION:
    % Ready-made UpdateFcn target for VNALiveView: mirrors the latest live
    % VNA data into app-level variables after every polling tick, so any
    % callback in the app can read the current frequency and S-parameter
    % arrays without touching the instrument.
    %
    % Define these properties in App Designer as PUBLIC (external functions
    % cannot write private app properties). Any that are missing are
    % skipped silently, so you only add the ones you need:
    %
    %   VNAFreqHz   - [npts x 1] sweep frequencies (Hz)
    %   VNASParams  - [npts x nTraces] display-format data (typically dB)
    %   VNASNames   - 1 x nTraces string, e.g. ["S11" "S21" ...]
    %   VNASComplex - [npts x nTraces] complex S-parameters (filled only
    %                 when the live view was built with 'StoreComplex',true)
    %
    % USAGE (Live View toggle callback):
    %   app.LiveView = VNALiveView(app.VNA, app.UIAxes, ...
    %       'UpdateFcn', @(meas) updateAppVNAData(app, meas));
    %
    % Then anywhere in the app, at any time:
    %   [~, fi] = min(abs(app.VNAFreqHz - 1.5e9));   % index of 1.5 GHz
    %   s21dB   = app.VNASParams(fi, app.VNASNames == "S21");
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if isprop(app, 'VNAFreqHz'),   app.VNAFreqHz   = meas.freqHz; end
    if isprop(app, 'VNASParams'),  app.VNASParams  = meas.data;   end
    if isprop(app, 'VNASNames'),   app.VNASNames   = meas.names;  end
    if isprop(app, 'VNASComplex'), app.VNASComplex = meas.sdata;  end
end
