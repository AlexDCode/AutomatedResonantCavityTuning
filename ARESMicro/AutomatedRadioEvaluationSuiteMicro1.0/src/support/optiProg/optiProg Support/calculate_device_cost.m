function [totalCost, sweepConstraints] = calculate_device_cost(app, gaps)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION: 
% This is the main function for calculating the cost (which we want to
% minimize) of the current gap distances for a variable cavity resonator, 
% using the conditions, target values, and weights set by the user.
%
% INPUT:
%   app            - MATLAB application object
%   gaps           - Current gaps between disk and plate of cavity
%                    resonator
% OUTPUT:
%   totalCost         -Total cost of the current gap positions (want to
%                      minimize this).
%   sweepConstraints  -Returns lowest transmission loss (S21 and S31) and 
%                      corresponding frequency for sweeping functions to use in minimizing sweeping range  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %S_names = ["S11", "S22", "S33", "S44", "S21", "S31", "S41"]; % S-params

    % 1. Reflection parameters: S11, S22, ..., SNN
    returnLossNames = "S" + (1:app.numActuators) + (1:app.numActuators)'; % Creates diagonal ["S11", "S22", ...]
    returnLossNames = returnLossNames(1:app.numActuators + 1:end); % Extract diagonal elements
    
    % 2. Transmission parameters from Port 1: S21, S31, ..., SN1
    if app.numActuators > 1
        transmissionNames = "S" + (2:app.numActuators) + "1";
    else
        transmissionNames = string.empty(1, 0); % Empty if only 1 port
    end
    
    % Combine into a single string array
    S_names = [returnLossNames, transmissionNames];
    
    % Update the actuator position
    commandAllGaps(app, gaps);
    
    % Let VNA Stabilize
    pause(1);
    
    % Get VNA data
    [freqs, S_params] = readCustomS(app.VNA, S_names);
    
    
    % use calc metric to get table for s-params
    
    % Create table components for the s-parameters:
    % S_param Name |centerFreq | peak Value | Mean Value|
    SName = {'S11', 'S22', 'S33', 'S44', 'S21', 'S31', 'S41'};
    SPeakFreq = zeros(numel(SName), 1);
    SPeak = zeros(numel(SName), 1);
    SMean = zeros(numel(SName), 1);
    
    % Loop through each s-parameter, using calcMetric to pass the relevant 
    % condition and data. Update the table with the peak value, the
    % corresponding frequency of the peak value, and the mean value over
    % the frequency range.
    for i = 1:numel(SName)
        
        if i <= app.numActuators %The number of diagnol value (return loss)
            [SPeakFreq(i), SPeak(i), SMean(i)] = calcMetric(app, freqs, S_params, app.userTData.Condition('ReturnLoss'), i);
        
        else
            [SPeakFreq(i), SPeak(i), SMean(i)] = calcMetric(app, freqs, S_params, app.userTData.Condition(SName{i}), i);

        end
    end
    
    % Build table of results
    ST = table(SPeakFreq, SPeak, SMean, 'RowNames',SName);

    totalCost = 0;
    
    % Return Loss Cost (S11, S22, S33, S44)
    returnLossCost = [ ...
        calcCost(app.userTData{'ReturnLoss', 'Condition'}, app.userTData{'ReturnLoss', 'Objective'}, app.userTData{'ReturnLoss', 'Weight'}, ST{'S11', 'SPeak'}), ...
        calcCost(app.userTData{'ReturnLoss', 'Condition'}, app.userTData{'ReturnLoss', 'Objective'}, app.userTData{'ReturnLoss', 'Weight'}, ST{'S22', 'SPeak'}), ...
        calcCost(app.userTData{'ReturnLoss', 'Condition'}, app.userTData{'ReturnLoss', 'Objective'}, app.userTData{'ReturnLoss', 'Weight'}, ST{'S33', 'SPeak'}), ...
        calcCost(app.userTData{'ReturnLoss', 'Condition'}, app.userTData{'ReturnLoss', 'Objective'}, app.userTData{'ReturnLoss', 'Weight'}, ST{'S44', 'SPeak'}) ...
    ];

    disp("Return Loss Cost: " + returnLossCost);
    disp("Return Loss:" + ST{'S11', 'SPeak'});
    disp("Return Loss:" + ST{'S22', 'SPeak'});
    disp("Return Loss:" + ST{'S33', 'SPeak'});
    disp("Return Loss:" + ST{'S44', 'SPeak'});

    totalCost = totalCost + mean(returnLossCost);
    
    % Insertion Loss / Transmission Costs (S21, S31, S41)
    totalCost = totalCost + calcCost(app.userTData{'S21', 'Condition'}, app.userTData{'S21', 'Objective'}, app.userTData{'S21', 'Weight'}, ST{'S21', 'SPeak'});
    totalCost = totalCost + calcCost(app.userTData{'S31', 'Condition'}, app.userTData{'S31', 'Objective'}, app.userTData{'S31', 'Weight'}, ST{'S31', 'SPeak'});
    totalCost = totalCost + calcCost(app.userTData{'S41', 'Condition'}, app.userTData{'S41', 'Objective'}, app.userTData{'S41', 'Weight'}, ST{'S41', 'SPeak'});

    disp("UP TO Insertion Cost: " + totalCost)
    
    % Frequency Drift Cost
    freqDriftCost = [ ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S11', 'SPeakFreq'}), ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S22', 'SPeakFreq'}), ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S33', 'SPeakFreq'}), ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S44', 'SPeakFreq'}), ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S21', 'SPeakFreq'}), ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S31', 'SPeakFreq'}), ...
        calcCost(app.userTData{'FreqDrift', 'Condition'}, app.userTData{'FreqDrift', 'Objective'}, app.userTData{'FreqDrift', 'Weight'}, ST{'S41', 'SPeakFreq'}) ...
    ];

    disp("Amp Imb. Cost: " + mean(freqDriftCost))

    totalCost = totalCost + mean(freqDriftCost);
    
    % Amplitude Imbalance Cost

    ampImbCost = calcCost( ...
        app.userTData{'AmplitudeImbalance', 'Condition'}, ...
        app.userTData{'AmplitudeImbalance', 'Objective'}, ...
        app.userTData{'AmplitudeImbalance', 'Weight'}, ...
        ST{'S21', 'SPeak'} - ST{'S31', 'SPeak'} ...
    );

    disp("Amp Imb. Cost: " + ampImbCost)

    totalCost = totalCost + ampImbCost;
    
    % Phase Imbalance Cost
    [~, peakIdx_21] = min(abs(freqs - ST{'S21', 'SPeakFreq'}));
    [~, peakIdx_31] = min(abs(freqs - ST{'S31', 'SPeakFreq'}));
    phase_21_rad = angle(S_params(1, peakIdx_21));
    phase_31_rad = angle(S_params(2, peakIdx_31));
    phase_diff_deg = rad2deg(abs(angdiff(phase_21_rad, phase_31_rad)));

    phaseCost =calcCost( ...
        app.userTData{'PhaseImbalance', 'Condition'}, ...
        app.userTData{'PhaseImbalance', 'Objective'}, ...
        app.userTData{'PhaseImbalance', 'Weight'}, ...
        phase_diff_deg ...
    );
    disp("Phase Cost: " + phaseCost)
    totalCost = totalCost + phaseCost;

    disp("COST: " + totalCost)

    % Finally for sweeping algorithms return this metric to help reduce
    % bandwidth of sweep (this is a struct).
    sweepConstraints.mag_21 = ST{'S21', 'SPeak'};
    sweepConstraints.freq_21 = ST{'S21', 'SPeakFreq'};
    sweepConstraints.mag_31 = ST{'S31', 'SPeak'};
    sweepConstraints.freq_31 = ST{'S31', 'SPeakFreq'};
end

