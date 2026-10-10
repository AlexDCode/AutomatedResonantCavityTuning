function commandLog(app)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% Sends the command to log the current gap values to the Pico.
%
% INPUT:
%   app            - MATLAB application object
%
% OUTPUT:
%   void
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    waitForResponse(app);
    cmdToSend = "log" + string(app.COMMANDS(3)) + " " + join(string(app.getGaps));
    writeline(app.pico, cmdToSend);
end