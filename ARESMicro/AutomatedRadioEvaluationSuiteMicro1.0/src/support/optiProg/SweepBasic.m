function [gaps, bestCost] = SweepBasic(app, gap_max)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% The function SweepBasic finds the best filter response by searching 
% for the peak insertion S-parameters, individually sweeping each
% actuator. It dynamically tracks the -10dB cut-off frequencies relative to a center frequency.
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
    peak_gaps = app.maxActuatorHeight .* ones(1, app.numActuators); % array to hold gaps corresponding to best response
    current_gaps = app.maxActuatorHeight .* ones(1, app.numActuators); % set the initial actuator heights
    bestCost = inf(app.numActuators, 1);

    % Normalize units: the GUI window and center_freq arrive in GHz while
    % the VNA axis is in Hz. An unset window falls back to the full sweep.
    if isempty(app.fmin) || isempty(app.fmax)
        warning('SweepBasic:NoFreqWindow', ...
            'Freq Min/Max not set in the app; searching the full sweep.');
        app.fmax = 20;
        app.fmin = 0;
    end
    app.fmin = toHz(app.fmin);
    app.fmax = toHz(app.fmax);
    app.desiredFCenter = toHz(app.desiredFCenter);

    %Pre-set all of the actuator heights to max
    commandAllGaps(app, current_gaps);
  
    % Iterate through all actuators
    for gap_num = 1:app.numActuators

        % Sweep through each gap value from 1 to gap_max
        for gap_dist = 1:app.startingStepSize:gap_max
            
            % Update actuator position
            commandIndividualGap(app, gap_num, gap_dist);
            pause(1.0);             % Let VNA Stabilize
            current_gaps(gap_num) = gap_dist;

            [total_cost, metrics] = calculate_device_cost(app, current_gaps);

            if bestCost(gap_num) > total_cost
                bestCost(gap_num) = total_cost;
                peak_gaps(gap_num) = gap_dist;
            end

            if app.targetCost >= bestCost(gap_num)
                peak_gaps = current_gaps;
                break;
            end

            get_Bounds(app, metrics.freq_21, metrics.mag_21);
            get_Bounds(app, metrics.freq_31, metrics.mag_31);
        end
            if app.targetCost >= bestCost(gap_num)
                break;
            end        
        % Set actuator back to max height
        commandAllGaps(app, peak_gaps)
        
    end

    % Assign the final results to the output variable and set actuator
    % positions
    gaps = peak_gaps;
    commandAllGaps(app, gaps)
    
end
