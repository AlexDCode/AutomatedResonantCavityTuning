function commandAllGaps(app, gaps)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% Sends the command for the Pico to calibrate actuator positions.
%
% INPUT:
%   app            - MATLAB application object
%
% OUTPUT:
%   void
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), round(gaps));
    writeline(app.pico, cmdToSend);
end