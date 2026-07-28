function extractPicoLog(app, CMD_EXTRACT_LOG)
    % --- EXPLICIT FILE CHECK & CREATION ---
    % If the file doesn't exist, touch it by opening in write mode ('w') and immediately closing it
    if ~isfile(app.localLogPath)
        fprintf("Local file '%s' not found. Creating it now...\n", app.localLogPath);
        fidTemp = fopen(localLogPath, 'w');
        if fidTemp == -1
            warning("OS blocked MATLAB from creating file at: %s. Check folder permissions.", localLogPath);
            return;
        else
            fclose(fidTemp);
        end
    end

    fclose('all'); 
    
    app.waitForResponse();
    %fprintf("Requesting log file from Pico internal flash...\n");
    
    writeline(app.pico, CMD_EXTRACT_LOG);

    app.PROMPT = "---START_FILE_TRANSFER---";
    app.waitForResponse();
    app.PROMPT = "EXECUTE:";

    localFileID = fopen(localLogPath, 'w+'); 
    if localFileID == -1
        warning("Could not open local log file: %s", localLogPath);
        return;
    end
    
    fprintf(app.localFileID, "--- Log Entry: %s ---\n", datestr(now));
    
    while true
        if app.pico.NumBytesAvailable > 0
            line = readline(app.pico);

            % Check for stop token sent by Python script
            if contains(line, "---END_FILE_TRANSFER---")
                %fprintf("File transfer complete!\n");
                break;
            end

            % Strip hidden carriage returns/newlines and write data line to file
            fprintf(app.localFileID, "%s\n", strtrim(line));
        end
        pause(0.005); 
    end
    
    fclose(localFileID); % Clean up active file handle safely
end