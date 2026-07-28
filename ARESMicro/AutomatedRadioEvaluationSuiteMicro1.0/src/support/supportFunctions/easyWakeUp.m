function easyWakeUp(app)
    app.ConnectionStatusActual.Text = 'Easy Wakeup';
    fprintf("Easy Wake Up\n");
    % Wake up the controller's program
    % Send Ctrl+C to get a clean prompt line
    write(app.pico, uint8(3), "uint8"); 
    pause(0.001);

    % Send the python command to execute your file, followed by a newline
    writeline(app.pico, "exec(open('main.py').read())"); 
end