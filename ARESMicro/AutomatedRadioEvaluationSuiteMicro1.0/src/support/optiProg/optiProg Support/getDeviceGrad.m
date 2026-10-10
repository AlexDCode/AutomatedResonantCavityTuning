function grad = getDeviceGrad(app, x, beta_, eta, cost, minCGap, span)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION: 
% Finds the updated gradient for the 'Live' model. 
%
% INPUT:
%   actuatorPos    -Actuator positon
%   cost_data      -vector of prior costs
%
% OUTPUT:
%   beta_           - actuator weights
%   P               - the covariance matrix
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Directional analytical surrogate gradient guidance normalized, scaled dynamically 
    [~, x_cap] = getDiskCapacitances(x);
    dirGrad = getAnalyticalGradient(app, x_cap, beta_);
    
    % Scaled step magnitude that smoothly decreases on convergence
    errorRatio = max(0.05, min(1.0, (cost - app.targetCost) / cost));
    maxStepLimit = 0.05 * span * errorRatio;
    
    if norm(dirGrad) > 1e-15
        grad = (dirGrad / norm(dirGrad)) * maxStepLimit;

        % Check if the step size (eta * gradNew) will push x below minCGap
        stepSize = eta .* grad;
        overshootMask = (x - stepSize) < minCGap;

        if any(overshootMask)
            % Scale down the gradient for overshooting channels so the step 
            % lands exactly at the minimum gap boundary
            grad(overshootMask) = (x(overshootMask) - minCGap) ./ eta(overshootMask);
        end
    else
        grad = zeros(1, 4);
    end
end