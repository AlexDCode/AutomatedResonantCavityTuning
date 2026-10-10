function easyWakeUp(app)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% Begins the execution of a new program on the Pico, given it is a
% currently connected object.
%
% INPUT:
%   app            - MATLAB application object
%
% OUTPUT:
%   void
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    app.ConnectionStatusActual.Text = 'Easy Wakeup';
    fprintf("Easy Wake Up\n");
    % Wake up the controller's program
    % Send Ctrl+C to get a clean prompt line
    write(app.pico, uint8(3), "uint8"); 
    pause(0.001);

    % Send the python command to execute your file, followed by a newline
    writeline(app.pico, "exec(open('main.py').read())"); 
end