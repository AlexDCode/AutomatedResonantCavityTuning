function plotVNATraces(ax, meas)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % plotVNATraces
    %
    % DESCRIPTION:
    % Plot a readVNATraces result onto a UI axes (or any axes). Intended for
    % the S-Parameters axes on the ARESMicro Tune tab; safe to call
    % repeatedly inside a tuning loop (it clears and redraws).
    %
    % INPUT:
    %   ax   - axes handle, e.g. app.UIAxes
    %   meas - struct from readVNATraces (.freqHz, .data, .names)
    %
    % USAGE:
    %   meas = readVNATraces(app.VNA);
    %   plotVNATraces(app.UIAxes, meas);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    cla(ax);
    plot(ax, meas.freqHz / 1e9, meas.data, 'LineWidth', 1.2);
    grid(ax, 'on');
    xlabel(ax, 'Frequency (GHz)');
    ylabel(ax, 'Magnitude (dB)');
    title(ax, 'S-Parameters');
    legend(ax, meas.names, 'Location', 'southeast');
    drawnow limitrate;
end
