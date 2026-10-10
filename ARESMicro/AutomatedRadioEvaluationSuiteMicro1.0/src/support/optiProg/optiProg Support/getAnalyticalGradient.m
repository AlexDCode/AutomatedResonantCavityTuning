function grad = getAnalyticalGradient(app, cap, beta_)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION: 
% Finds the analytical gradient for the surrogate model, but can be used to
% find the unit vector for the 'Live' model. 
%
% INPUT:
%   app            - MATLAB application object
%   cap            - capacitances of each actuator
%   beta_          - actuator weights
%
% OUTPUT:
%   grad           - updated gradient 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute the current predicted performance Y(x) using clean column operations
    Y_curr = beta_(1) + ...
             sum(beta_(2:5) .* cap) + ...                             % Linear terms (dot product)
             sum(beta_(6:9) .* (cap.^2)) + ...                        % Quadratic terms (dot product)
             beta_(10)*cap(1)*cap(2) + beta_(11)*cap(1)*cap(3) + beta_(12)*cap(1)*cap(4) + ...
             beta_(13)*cap(2)*cap(3) + beta_(14)*cap(2)*cap(4) + ...
             beta_(15)*cap(3)*cap(4);

    % Compute the outer derivative multiplier: 2 * (Y(x) - Y_target)
    outer = 2 * (Y_curr - app.targetCost);
    
    % Compute the inner partial derivatives dY/dxi
    dY_dx1 = beta_(2) + 2*beta_(6)*cap(1)  + beta_(10)*cap(2) + beta_(11)*cap(3) + beta_(12)*cap(4);
    dY_dx2 = beta_(3) + 2*beta_(7)*cap(2)  + beta_(10)*cap(1) + beta_(13)*cap(3) + beta_(14)*cap(4);
    dY_dx3 = beta_(4) + 2*beta_(8)*cap(3)  + beta_(11)*cap(1) + beta_(13)*cap(2) + beta_(15)*cap(4);
    dY_dx4 = beta_(5) + 2*beta_(9)*cap(4)  + beta_(12)*cap(1) + beta_(14)*cap(2) + beta_(15)*cap(3);

    % Combine to form the final 4x1 gradient column vector
    grad = outer .* [dY_dx1, dY_dx2, dY_dx3, dY_dx4]; %.* 1e-12
end