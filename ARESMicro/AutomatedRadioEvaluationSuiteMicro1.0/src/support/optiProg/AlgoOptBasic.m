function [gaps, peak_db, peak_freq, fmin, fmax] = AlgoOptBasic(app, freq_min, freq_max, gap_max, num_actuators, indexPrecision, center_freq)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % DESCRIPTION:
    % The function AlgoOptBasic finds the best filter response by searching 
    % for the peak insertion S-parameters by individually sweeping each actuator.
    % It dynamically tracks the -10dB cut-off frequencies relative to a center frequency.
    %
    % INPUT:
    %   app            - DEF
    %   freq_min       - Minimum frequency constraint (in Hz)
    %   freq_max       - Maximum frequency constraint (in Hz)
    %   gap_max        - DEF
    %   num_actuators  - DEF
    %   indexPrecision - DEF
    %   center_freq    - User-defined center frequency (in Hz) to split fmin and fmax tracking
    %
    % OUTPUT:
    %   gaps           - Array of gaps corresponding to best response
    %   peak_db        - Peak magnitudes found
    %   peak_freq      - Frequencies at peak magnitudes
    %   fmin           - Lower -10dB cut-off frequencies
    %   fmax           - Upper -10dB cut-off frequencies
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Setup Variables
    max_height = 4000; % removes the capacitance from an actuator by setting it high
    peak_freq = zeros(1, num_actuators); % array to hold peak frequencies
    peak_db   = -inf(1, num_actuators);  % array to hold peak magnitudes
    peak_gaps = zeros(1, num_actuators); % array to hold gaps corresponding to best response
    starting_gaps = max_height .* ones(1, num_actuators); % set the initial actuator heights
    S_params = ["S21", "S31"]; % S-params needed for algorithm
    fmin = nan(1, num_actuators); % lower -10 dB cutoff per actuator, NaN until found
    fmax = nan(1, num_actuators); % upper -10 dB cutoff per actuator, NaN until found

    % Normalize units: the GUI window and center_freq arrive in GHz while
    % the VNA axis is in Hz. An unset window falls back to the full sweep.
    if isempty(freq_min) || isempty(freq_max)
        warning('AlgoOptBasic:NoFreqWindow', ...
            'Freq Min/Max not set in the app; searching the full sweep.');
        freq_min = -inf;
        freq_max = inf;
    end
    freq_min = toHz(freq_min);
    freq_max = toHz(freq_max);
    center_freq = toHz(center_freq);

    %Pre-set all of the actuator heights to max
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), starting_gaps);
    writeline(app.pico, cmdToSend);
  
    % Iterate through all actuators
    for gap_num = 1:num_actuators

        % Sweep through each gap value from 1 to gap_max
        for gap_dist = 1:indexPrecision:gap_max

            % Update actuator position
            waitForResponse(app);
            cmdToSend = sprintf("%s %d %d", app.COMMANDS(5), gap_num, gap_dist);
            writeline(app.pico, cmdToSend);

            % Let VNA Stabilize
            pause(1.0);

            % Select the desired traces from VNA
            [f, S] = readCustomS(app.VNA, S_params);
      
            % Checks if S21 or S31 should be analyzed based on which gaps
            % are being moved
            if gap_num < 3
                [curr_freq, curr_db] = find_sparam_peak(f, S(1,:), freq_min, freq_max); 
            
            else
                [curr_freq, curr_db] = find_sparam_peak(f, S(2,:), freq_min, freq_max); 
            end
            
            % Updates best responses/values
            if curr_db > peak_db(gap_num)
                peak_db(gap_num)   = curr_db;
                peak_freq(gap_num) = curr_freq;
                peak_gaps(gap_num) = gap_dist;
            end

            % Check if the current peak magnitude is at or below -10dB
            if curr_db >= -10 && curr_db <= -9.5
                if curr_freq < center_freq
                    % Update fmin if it's currently empty, or if the new frequency is larger 
                    % (moving closer to the center frequency from the left skirt)
                    if isnan(fmin(gap_num)) || curr_freq > fmin(gap_num)
                        fmin(gap_num) = curr_freq;
                    end
                else
                    % Update fmax if it's currently empty, or if the new frequency is smaller
                    % (moving closer to the center frequency from the right skirt)
                    if isnan(fmax(gap_num)) || curr_freq < fmax(gap_num)
                        fmax(gap_num) = curr_freq;
                    end
                end
            end
        end

        % Set actuator back to max height
        waitForResponse(app);
        cmdToSend = sprintf("%s %d %d", app.COMMANDS(5), gap_num, max_height);
        writeline(app.pico, cmdToSend);
    end

    % Assign the final results to the output variable and set actuator
    % positions
    gaps = peak_gaps;
    
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), gaps);
    writeline(app.pico, cmdToSend);
end
