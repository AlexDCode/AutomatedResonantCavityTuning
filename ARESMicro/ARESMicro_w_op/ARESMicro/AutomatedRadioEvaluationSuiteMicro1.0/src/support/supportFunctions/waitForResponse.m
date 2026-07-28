function waitForResponse(app)
    if ~isempty(app.pico) && isvalid(app.pico)
        while true
            % Only try to read if there is actually text waiting in the buffer
            if app.pico.NumBytesAvailable > 0
                response = readline(app.pico);
                disp("Received: " + strtrim(string(response)));
                
                % Check if we found our target
                if contains(string(response), app.PROMPT)
                    break; % Exit the loop safely
                end
            else
                % If buffer is empty, wait a tiny bit and check again
                pause(0.01); 
            end
        end
    else
        app.isSetup = false;
    end
end