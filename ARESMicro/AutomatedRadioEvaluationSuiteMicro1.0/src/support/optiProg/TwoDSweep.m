function [peak_gaps, bestCost] = TwoDSweep(app, gap_max)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% The function TwoDSweep is an algorithm which finds the
% best filter response by searching for the peak insertion
% S-parameters. It first finds the peak S21 value for gap 1, holding
% gap 1, the peak S31 value is found by iterating gap 3 and gap 4. This
% process is repeated for gap 2. 
%
% It can handle up to four actuator inputs. 
%
% INPUT:
%   app            - MATLAB application object
%   gap_max        - maximum gap limit
%
% OUTPUT:
%   gaps           - best found gaps
%   bestCost       - best (minimized) cost corresponding to the best
%                    gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Setup Variables
    peak_gaps = ones(1, app.numActuators); % array to hold gaps corresponding to best response
    current_gaps = app.maxActuatorHeight .* ones(1, app.numActuators); % set the initial actuator heights and holds the current gap values
    current_cost = inf(1, app.numActuators); %Vector containing the current best (minimized) cost values

    % Normalize the analysis window: the GUI fields are in GHz while the
    % VNA axis (and the get_Bounds tracking below) is in Hz. An unset
    % window falls back to the full sweep instead of erroring.
    if isempty(app.fmin) || isempty(app.fmax)
        warning('TwoDSweep:NoFreqWindow', ...
            'Freq Min/Max not set in the app; searching the full sweep.');
        app.fmin = 0;
        app.fmax = 20;
    end

    app.fmin = toHz(app.fmin);
    app.fmax = toHz(app.fmax);
    app.desiredFCenter = toHz(app.desiredFCenter);

    %Pre-set all of the actuator heights to max
    commandAllGaps(app, current_gaps)
  
    % Iterate through the main path gaps (Gap 1 and Gap 2)
    for gap_num = 1:2

        % Sweep through each gap value from 1 to gap_max
        for gap_dist = 1:app.startingStepSize:gap_max
            
            current_gaps(gap_num) = gap_dist;

            % Update actuator position
            commandIndividualGap(app, gap_num, gap_dist);
            pause(1.0);             % Let VNA Stabilize
            
            [total_cost, metrics] = calculate_device_cost(app, current_gaps);

            if current_cost(gap_num) > total_cost
                current_cost(gap_num) = total_cost;
                peak_gaps(gap_num) = gap_dist;
            end
            
            % Check if -10dB point is reached to shorten the sweeping range
            get_Bounds(app, metrics.freq_21, metrics.mag_21);

        end
        
        % Update the first swept actuator to its best value
        current_gaps(gap_num) = peak_gaps(gap_num);
        
        % Repeat, maximize transmission to Port 3 (S31)
        index = 3;
        for gap_dist = 1:app.startingStepSize:gap_max
            current_gaps(index) = gap_dist;
            
            commandAllGaps(app, current_gaps);
            pause(1.0);

            [total_cost, metrics] = calculate_device_cost(app, current_gaps);

            if current_cost(index) > total_cost
                current_cost(index) = total_cost;
                peak_gaps(index) = gap_dist;
            end
            
            get_Bounds(app, metrics.freq_31, metrics.mag_31);
        end
        
        %set the actuator out of the way
        current_gaps(index) = app.maxActuatorHeight;
        commandIndividualGap(app, index, current_gaps(index))
        
        % Repeat for gap 4: minimize transmission to Port 4 (S41)
        index = 4;
        for gap_dist = 1:app.startingStepSize:gap_max
            current_gaps(index) = gap_dist;
            
            commandAllGaps(app, current_gaps);
            pause(1.0);

            [total_cost, ~] = calculate_device_cost(app, current_gaps);

            if current_cost(index) > total_cost
                current_cost(index) = total_cost;
                peak_gaps(index) = gap_dist;
            end
            
        end

        %set the actuator out of the way
        current_gaps(index) = app.maxActuatorHeight;
        commandIndividualGap(app, index, current_gaps(index))

    end
    
    % Assign the final results to the output variable and update all gaps
    [bestCost, ~] = calculate_device_cost(app, peak_gaps);
    commandAllGaps(app, peak_gaps);
end