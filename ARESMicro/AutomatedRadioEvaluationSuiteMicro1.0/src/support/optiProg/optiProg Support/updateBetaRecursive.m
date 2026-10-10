function [beta_new, P_new] = updateBetaRecursive(x_new, cost_new, beta_old, P_old)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Description: 
% Updates beta parameters using a single new measurement from gradient descent.
%
% Inputs:
%   x_new    - 1 x 4 vector of physical gaps (mm) of the new state
%   cost_new - Scalar real cost of this new position
%   beta_old - Current 15x1 beta vector
%   P_old    - Current 15x15 covariance matrix
% 
% Outputs:
%   beta_new - the updated beta parameter
%   P_new    - the updated covariance matrix
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    lambda = 0.95; % Forgetting factor (0.9 to 0.99). Lower = tracks local physics faster.
    
    % Get capacitance values (in pF)
    [~, x_cap] = getDiskCapacitances(x_new);
    
    % Build the single-row regressor vector (15 x 1 column)
    phi = [1; ...                                    % Intercept
           x_cap'; ...                               % Linear
           (x_cap.^2)'; ...                          % Curvatures
           x_cap(1)*x_cap(2); ...                    % Coupling 1-2
           x_cap(1)*x_cap(3); ...                    % Coupling 1-3
           x_cap(1)*x_cap(4); ...                    % Coupling 1-4
           x_cap(2)*x_cap(3); ...                    % Coupling 2-3
           x_cap(2)*x_cap(4); ...                    % Coupling 2-4
           x_cap(3)*x_cap(4)];                       % Coupling 3-4
       
    % Calculate local prediction error based on our existing model
    predicted_cost = phi' .* beta_old;
    err = cost_new - predicted_cost;
    
    % RLS gain update
    K = (P_old .* phi) ./ (lambda + phi' .* P_old .* phi);
    
    % Update parameters & covariance matrix
    beta_new = beta_old + K .* err;
    P_new = (P_old - K .* phi' .* P_old) ./ lambda;
end