function [beta_, P] = getBetaConstants(actuatorPos, cost_data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION: 
% Finds the analytical gradient for the surrogate model, but can be used to
% find the unit vector for the 'Live' model. 
%
% INPUT:
%   actuatorPos    -Actuator positon
%   cost_data      -vector of prior costs
%
% OUTPUT:
%   beta_           - actuator weights
%   P               - the covariance matrix
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETBETACONSTANTS Fits an all-to-all coupled surrogate matrix using your exact C2 model.
    %
    % Inputs:
    %   actuatorPos : An N x 4 matrix of physical actuator gaps (in um)
    %   cost_data   : An N x 1 vector of scalar costs calculated from VNA sweeps.
    numPoints = length(actuatorPos);
    
    % Extract exact capacitance values mapping to the true physics of C2
    [~, x_cap] = getDiskCapacitances(actuatorPos); 
  
    % Build the High-Fidelity Regression Design Matrix (X_reg)
    X_reg = [ones(numPoints, 1), ...            % Intercept
             x_cap, ...                         % Linear (x1, x2, x3, x4)
             x_cap.^2, ...                      % Self-Loading Curvatures
             x_cap(:,1).*x_cap(:,2), ...        % Coupling 1-2
             x_cap(:,1).*x_cap(:,3), ...        % Coupling 1-3
             x_cap(:,1).*x_cap(:,4), ...        % Coupling 1-4
             x_cap(:,2).*x_cap(:,3), ...        % Coupling 2-3
             x_cap(:,2).*x_cap(:,4), ...        % Coupling 2-4
             x_cap(:,3).*x_cap(:,4)];           % Coupling 3-4
         
    % Solve the overdetermined linear system
    % Add tiny regularization to prevent ill-conditioned matrix warnings
    alpha = 1e-6; 
    A = X_reg' * X_reg + alpha * eye(15);
    b_vec = X_reg' * cost_data;
    
    beta_ = A \ b_vec;
    if iscolumn(beta_)
        beta_ = beta_.';
    end
    P = inv(A);
end