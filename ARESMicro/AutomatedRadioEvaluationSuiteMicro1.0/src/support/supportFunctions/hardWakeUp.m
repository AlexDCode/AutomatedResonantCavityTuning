function hardWakeUp(app)
    app.ConnectionStatusActual.Text = 'Hard Wakeup';
    fprintf("Waking up Pico and exiting Raw REPL...\n");
    
    % 1. Send Ctrl+C to interrupt anything currently hanging
    write(app.pico, uint8(3), "uint8"); 
    pause(0.001);
    
    % 2. Send Ctrl+B to explicitly exit Raw REPL mode if stuck there
    write(app.pico, uint8(2), "uint8"); 
    pause(0.001);
    
    % 3. Send Ctrl+D to soft-reboot into normal execution mode
    write(app.pico, uint8(4), "uint8"); 
end