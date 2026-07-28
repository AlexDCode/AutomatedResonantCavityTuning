function [gaps, peak_db, peak_freq, freq_min, freq_max] = AlgoOpt(app, freq_min, freq_max, gap_max, num_actuators, indexPrecision)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % DESCRIPTION:
    % The function AlgoOpt is an algorithm which finds the
    % best filter response by searching for the peak insertion
    % S-parameters. It first finds the peak S21 value for gap 1, holding
    % gap 1, the peak S31 value is found by iterating gap 3 and gap 4. This
    % process is repeated for gap 2.
    %
    % INPUT:
    %   app            - DEF
    %   freq_min       - DEF
    %   freq_max       - DEF
    %   gap_max        - DEF
    %   num_actuators  - DEF
    %   indexPrecision - DEF
    %
    % OUTPUT:
    %   gaps           - DEF
    %   peak_db        - DEF
    %   peak_freq      - DEF
    %   freq_min       - DEF
    %   freq_max       - DEF
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Setup Variables
    max_height = 4000; % removes the capacitance from an actuator by setting it high
    peak_freq = zeros(1, num_actuators); % array to hold peak frequencies
    peak_db   = -inf(1, num_actuators);  % array to hold peak magnitudes
    peak_gaps = zeros(1, num_actuators); % array to hold gaps corresponding to best response
    starting_gaps = max_height .* ones(1, num_actuators); % set the initial actuator heights
    S_params = ["S21", "S31"]; % S-params needed for algorithm

    % Normalize the analysis window: the GUI fields are in GHz while the
    % VNA axis (and the get_Bounds tracking below) is in Hz. An unset
    % window falls back to the full sweep instead of erroring.
    if isempty(freq_min) || isempty(freq_max)
        warning('AlgoOpt:NoFreqWindow', ...
            'Freq Min/Max not set in the app; searching the full sweep.');
        freq_min = -inf;
        freq_max = inf;
    end
    freq_min = toHz(freq_min);
    freq_max = toHz(freq_max);

    %Pre-set all of the actuator heights to max
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps);
    writeline(app.pico, cmdToSend);
  
    % Iterate through the main path gaps (Gap 1 and Gap 2)
    for gap_num = 1:2

        % Sweep through each gap value from 1 to gap_max
        for gap_dist = 1:indexPrecision:gap_max
            
            % Update actuator position
            waitForResponse(app);
            cmdToSend = sprintf("%s %d %d", app.COMMANDS(5), gap_num, gap_dist);
            writeline(app.pico, cmdToSend);
           
            % Let VNA Stabilize
            pause(1.0);

            % Select the desired traces
            [f, S] = readCustomS(app.VNA, S_params);
            [curr_freq, curr_db] = find_sparam_peak(f, S(1,:), freq_min, freq_max); 
            
            % Update the best values
            if curr_db > peak_db(gap_num)
                peak_db(gap_num)   = curr_db;
                peak_freq(gap_num) = curr_freq;
                peak_gaps(gap_num) = gap_dist;
            end
            
            % Check if -10dB point is reached to shorten the sweeping range
            [freq_max, freq_min] = get_Bounds(curr_db, curr_freq, freq_max, freq_min, peak_freq(gap_num));

        end

        starting_gaps(gap_num) = peak_gaps(gap_num);
        
        % Repeat for gap 3: maximize transmission to Port 3 (S31)
        for gap_dist = 1:indexPrecision:gap_max
            starting_gaps(3) = gap_dist;
            
            waitForResponse(app);
            cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps(1), starting_gaps(2), gap_dist, starting_gaps(4));
            writeline(app.pico, cmdToSend);
            
            pause(1.0);

            [f, S] = readCustomS(app.VNA, S_params);
            [curr_freq, curr_db] = find_sparam_peak(f, S(2,:), freq_min, freq_max); 
                            
            if curr_db > peak_db(3)
                peak_db(3)   = curr_db;
                peak_freq(3) = curr_freq;
                peak_gaps(3) = gap_dist;
            end
            
            [freq_max, freq_min] = get_Bounds(curr_db, curr_freq, freq_max, freq_min, peak_freq(3));

        end

        starting_gaps(3) = max_height;
        
        % Repeat for gap 4: maximize transmission to Port 4 (S41)
        for gap_dist = 1:indexPrecision:gap_max
            starting_gaps(4) = gap_dist;
            
            waitForResponse(app);
            cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps(1), starting_gaps(2), starting_gaps(3), gap_dist);
            writeline(app.pico, cmdToSend);
            
            pause(1.0);

            [f, S] = readCustomS(app.VNA, S_params);
            [curr_freq, curr_db] = find_sparam_peak(f, S(2,:), freq_min, freq_max);  
            
            if curr_db > peak_db(4)
                peak_db(4)   = curr_db;
                peak_freq(4) = curr_freq;
                peak_gaps(4) = gap_dist;
            end
            
            [freq_max, freq_min] = get_Bounds(curr_db, curr_freq, freq_max, freq_min, peak_freq(4));

        end
    starting_gaps(4) = max_height;
    starting_gaps(gap_num) = max_height;

    % Assign the final results to the output variable and update all gaps
    gaps = peak_gaps;
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), gaps);
    writeline(app.pico, cmdToSend);
    end
end

function [fmax, fmin] = get_Bounds(curr_db, curr_freq, curr_max, curr_min, peak_freq)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % DESCRIPTION:
    % Check if -10dB point is reached to shorten the sweeping range.
    %
    % INPUT:
    %   curr_db        - DEF
    %   curr_freq      - DEF
    %   curr_max       - DEF
    %   curr_min       - DEF
    %   peak_freq      - DEF
    %
    % OUTPUT:
    %   fmax           - DEF
    %   fmin           - DEF
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Default: keep the current range (both outputs must be assigned on
    % every path or MATLAB errors with "Output argument not assigned")
    fmax = curr_max;
    fmin = curr_min;

    % Check if the -10 dB value is reached
    if curr_db >= -10 && curr_db <= -9.7
        % A -10 dB point below the peak raises the lower bound; one above
        % the peak lowers the upper bound. The window only ever narrows.
        if curr_freq < peak_freq && curr_freq > curr_min
            fmin = curr_freq;
        elseif curr_freq > peak_freq && curr_freq < curr_max
            fmax = curr_freq;
        end
    end
end

%OLD CODE Does not consider -10dB point
% function [gaps, peak_db, peak_freq] = AlgoOpt(app, freq_min, freq_max, gap_max, num_actuators, indexPrecision)
% 
%     % Trackers
%     max_height = 4000;
%     peak_freq = zeros(1, num_actuators); %Note: Gaps 1 and 2 correlate to S21 and gaps 3 and 4 correlate to S31
%     peak_db   = -inf(1, num_actuators); %Note: Gaps 1 and 2 correlate to S21 and gaps 3 and 4 correlate to S31 
%     peak_gaps = zeros(1, num_actuators); %best found actuator gap values
%     starting_gaps = max_height .* ones(1, num_actuators); %sets the starting gap values
%     S_params = ["S21", "S31"]; %S params needed for this algorithm
% 
%     %Pre-set all of the actuator heights to max
%     waitForResponse(app);
%     cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps);
%     writeline(app.pico, cmdToSend);
% 
%     % Iterate through the main path gaps (Gap 1 and Gap 2)
%     for gap_num = 1:2
%         % Sweep through each gap value from 1 to gap_max
%         for gap_dist = 1:indexPrecision:gap_max
% 
%             waitForResponse(app);
%             cmdToSend = sprintf("%s %d %d", app.COMMANDS(5), gap_num, gap_dist);
%             writeline(app.pico, cmdToSend);
% 
%             %Let VNA Stabilize
%             pause(1.0);
% 
%             %select the desired traces
%             [f, S] = readCustomS(app.VNA, S_params);
% 
%             [curr_freq, curr_db] = find_sparam_peak(f, S(1,:), freq_min, freq_max); 
% 
%             if curr_db > peak_db(gap_num)
%                 peak_db(gap_num)   = curr_db;
%                 peak_freq(gap_num) = curr_freq;
%                 peak_gaps(gap_num) = gap_dist;
%             end
%         end
% 
%         starting_gaps(gap_num) = peak_gaps(gap_num);
% 
%         % Repeat for gap 3: maximize transmission to Port 3 (S31)
%         for gap_dist = 1:indexPrecision:gap_max
%             starting_gaps(3) = gap_dist;
% 
%             waitForResponse(app);
%             cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps(1), starting_gaps(2), gap_dist, starting_gaps(4));
%             writeline(app.pico, cmdToSend);
% 
%             %Let VNA Stabilize
%             pause(1.0);
% 
%             [f, S] = readCustomS(app.VNA, S_params);
% 
%             [curr_freq, curr_db] = find_sparam_peak(f, S(2,:), freq_min, freq_max); 
% 
%             if curr_db > peak_db(3)
%                 peak_db(3)   = curr_db;
%                 peak_freq(3) = curr_freq;
%                 peak_gaps(3) = gap_dist;
%             end
%         end
% 
%         starting_gaps(3) = max_height;
% 
%         % Repeat for gap 4: maximize transmission to Port 4 (S41)
%         for gap_dist = 1:indexPrecision:gap_max
%             starting_gaps(4) = gap_dist;
% 
%             waitForResponse(app);
%             cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps(1), starting_gaps(2), starting_gaps(3), gap_dist);
%             writeline(app.pico, cmdToSend);
% 
% 
%             %Let VNA Stabilize
%             pause(1.0);
% 
%             [f, S] = readCustomS(app.VNA, S_params);
% 
%             [curr_freq, curr_db] = find_sparam_peak(f, S(2,:), freq_min, freq_max);  
% 
%             if curr_db > peak_db(4)
%                 peak_db(4)   = curr_db;
%                 peak_freq(4) = curr_freq;
%                 peak_gaps(4) = gap_dist;
%             end
%         end
% 
%         starting_gaps(4) = max_height;
%         starting_gaps(1) = max_height;
%     end
% 
%     % Assign the final results to the output variable
%     gaps = peak_gaps;
% 
%     waitForResponse(app);
%     cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), gaps);
%     writeline(app.pico, cmdToSend);
% end