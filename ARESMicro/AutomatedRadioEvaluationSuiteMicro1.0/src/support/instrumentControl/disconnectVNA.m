function disconnectVNA(vna, liveView)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % disconnectVNA
    %
    % DESCRIPTION:
    % Cleanly release the VNA: stop a live view's polling timer first, hand
    % the instrument back to the operator in free-running sweep, then close
    % the connection.
    %
    % This function NEVER throws — it is safe in a Disconnect button, the
    % app's delete(), or any cleanup path, even when nothing was ever
    % connected, the object is a stale/deleted handle, or the instrument
    % has already been unplugged (in which case the "restore continuous"
    % nicety is skipped and the local connection is still torn down).
    %
    % INPUT:
    %   vna      - VNAInstCtrl from connectVNA, or [] / stale handle
    %   liveView - (optional) VNALiveView to stop first, or [] / stale handle
    %
    % USAGE (Disconnect button callback):
    %   disconnectVNA(app.VNA, app.LiveView);
    %   app.VNA = [];
    %   app.LiveView = [];
    %   app.VNAStatusLabel.Text = 'Status: Disconnected';
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % The polling timer must die BEFORE the connection: a tick that fires
    % against a closed transport would error (and auto-stop with a warning,
    % but there is no reason to let it race).
    if nargin >= 2 && ~isempty(liveView) && isa(liveView, 'VNALiveView') ...
            && isvalid(liveView)
        try liveView.stop(); catch, end
    end

    if ~isempty(vna) && isa(vna, 'SCPIInstrument') && isvalid(vna)
        if vna.IsConnected && ismethod(vna, 'setContinuous')
            % Best effort: give the operator a live front-panel display.
            try vna.setContinuous(true); catch, end
        end
        try vna.disconnect(); catch, end
    end
end
