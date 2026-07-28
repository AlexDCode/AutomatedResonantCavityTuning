function [gaps, peak_db, peak_freq, freq_min, freq_max] = centeredAlgoOpt(app, freq_min, freq_max, gap_max, num_actuators, indexPrecision, desiredCenterFreq, goals)
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

    % goals: weighted in order
    goal1 = -5; %S21 and S31 should be above this value
    goal2 = 1; %|S21 - S31| should be less than this

    % Normalize units: the GUI window and desiredCenterFreq arrive in GHz
    % while the VNA axis is in Hz. An unset window falls back to the full
    % sweep.
    if isempty(freq_min) || isempty(freq_max)
        warning('centeredAlgoOpt:NoFreqWindow', ...
            'Freq Min/Max not set in the app; searching the full sweep.');
        freq_min = -inf;
        freq_max = inf;
    end
    freq_min = toHz(freq_min);
    freq_max = toHz(freq_max);
    desiredCenterFreq = toHz(desiredCenterFreq);

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
            
            % Update the best values at the wanted center frequency while
            % meeting the goals
            % On-center within half a grid step (exact == never matches a
            % discrete sweep grid)
            if curr_db > goal1 && abs(curr_freq - desiredCenterFreq) <= median(diff(f)) / 2
                if curr_db > peak_db(gap_num)
                    peak_db(gap_num)   = curr_db;
                    peak_freq(gap_num) = curr_freq;
                    peak_gaps(gap_num) = gap_dist;
                end
            end

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
                            
            % On-center within half a grid step (exact == never matches a
            % discrete sweep grid)
            if curr_db > goal1 && abs(curr_freq - desiredCenterFreq) <= median(diff(f)) / 2
                if curr_db > peak_db(gap_num)
                    peak_db(gap_num)   = curr_db;
                    peak_freq(gap_num) = curr_freq;
                    peak_gaps(gap_num) = gap_dist;
                end
            end

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
            
            % On-center within half a grid step (exact == never matches a
            % discrete sweep grid)
            if curr_db > goal1 && abs(curr_freq - desiredCenterFreq) <= median(diff(f)) / 2
                if curr_db > peak_db(gap_num)
                    peak_db(gap_num)   = curr_db;
                    peak_freq(gap_num) = curr_freq;
                    peak_gaps(gap_num) = gap_dist;
                end
            end

        starting_gaps(4) = max_height;
        starting_gaps(gap_num) = max_height;
        end

    % Assign the final results to the output variable and update all gaps
    gaps = peak_gaps;
    
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), gaps);
    writeline(app.pico, cmdToSend);
    end
end