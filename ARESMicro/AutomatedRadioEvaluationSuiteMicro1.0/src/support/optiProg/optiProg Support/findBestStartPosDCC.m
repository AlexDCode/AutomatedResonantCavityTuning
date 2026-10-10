function [bestGaps, maxCGap, minCGap, minOverallCost, worstCost, beta_, coVar, span] = findBestStartPosDCC(app)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Description:
% Uses CCD to find the optimal start positions for gradient descent. 
%
%   Input
%     app            - MATLAB application object
%    
%   Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Generate the 4-factor central composite design
    dCC = unique(ccdesign(4, 'Type', 'faced'), 'rows', 'stable');

    maxCGap = round(findMaxGap());
    minCGap = 10;
    
    midCGap = sqrt(minCGap * maxCGap); % Because gap values are logarithmic, not linear.
    actuatorPos = round(midCGap) * ones(size(dCC));
    worstCost = 0;
    
    % Define the physical actuator travel range
    span = maxCGap - minCGap;

    actuatorPos(dCC == 1) = maxCGap;
    actuatorPos(dCC == -1) = minCGap;
    
    % Track the overall optimal configuration
    minOverallCost = inf; 
    bestGaps = midCGap * ones(4,1); 
    bestFreq = [0, 0];
    bestMag = [-inf, -inf]; 
    
    numPoints = length(actuatorPos);

    % Array to store the cost associated with each measurement
    cost_data = zeros(numPoints, 1);

    for row = 1:numPoints
        
        [total_cost, metrics] = calculate_device_cost(app, actuatorPos(row, :));
        
        % Store the cost for our surrogate regression mapping
        cost_data(row) = total_cost;

        % Check if this configuration is our new overall global winner
        if total_cost < minOverallCost
            disp("Cost: " + minOverallCost)
            minOverallCost = total_cost;
            bestGaps = actuatorPos(row, :); 
            bestFreq = [metrics.freq_21, metrics.freq_31];
            bestMag  = [metrics.mag_21, metrics.mag_31];
        end

        if total_cost > worstCost
            worstCost = total_cost;
        end
    end

    %Get beta values for objective function
    [beta_, coVar] = getBetaConstants(actuatorPos, cost_data);
end
