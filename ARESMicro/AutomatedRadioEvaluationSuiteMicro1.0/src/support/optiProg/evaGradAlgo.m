function bestGaps = evaGradAlgo(app, freq_min, freq_max, weights, useSurr, variableEta)
    %% GET INITIAL VALUES
    targetCost = 1.3;
    S_params = ["S21", "S31", "S11"];
    maxIteration = 25;

    etaMin = 1e-4;
    etaMax = 0.5;

    eta = repmat(etaMax, 1, 4);
    gradNew = zeros(4, 1);

    minCGap = 1;
    iteration = 0;

    costHistory = NaN(maxIteration);
    gapHistory = NaN(maxIteration, 4);
    etaHistory = NaN(3, 4);
    
    [bestGaps, maxCGap, ~, cost, worstCost, beta_, coVar, span] = findBestStartPos(app, weights, freq_min, freq_max, S_params, useSurr);
    disp("Best Gaps: " + mat2str(bestGaps))

    %This is the theoretical cost
    objectiveFunction = @(x) ( ...
        beta_(1) + ...                                                       % Intercept / Base state
        sum(beta_(2:5)' .* x) + ...                                       % Linear sensitivities (x1, x2, x3, x4)
        sum(beta_(6:9)' .* (x.^2)) + ...                                  % Self-loading curvatures (x1^2, x2^2, x3^2, x4^2)
        beta_(10)*x(1)*x(2) + beta_(11)*x(1)*x(3) + beta_(12)*x(1)*x(4) + ...  % Cross-couplings from Cavity 1
        beta_(13)*x(2)*x(3) + beta_(14)*x(2)*x(4) + ...                       % Cross-couplings from Cavity 2
        beta_(15)*x(3)*x(4) ...                                              % Cross-coupling between 3 and 4
        - targetCost ...
    ).^2;
    
    if useSurr
        % x represents capacitance because the formulas are more linear
        [~, x] = getDiskCapacitances(bestGaps);
        grad = getAnalyticalGradient(x, beta_, targetCost);

        %Normalize Objective function
        %normalizer =  mean(objectiveFunction(x)) / cost;
        surrogateScaleFactor = cost / mean(objectiveFunction(x));

    else
        x = bestGaps;
        grad = getDeviceGrad(x, beta_, eta, cost, targetCost, minCGap, span);
    end

    
    %% ENTER MAIN LOOP
    while cost > targetCost && iteration < maxIteration
        iteration = iteration + 1;
        xNew = x - (eta .* grad);

        if useSurr
            % Calculate new raw positions

            % If using surrogate, we must clip capacitances to prevent physically impossible bounds
            [~, minC] = getDiskCapacitances(repmat(maxCGap, 1, 4));
            [~, maxC] = getDiskCapacitances(repmat(minCGap, 1, 4));
         
            xNew = min(max(xNew, minC), maxC);
        else
            xNew = round(xNew); 
            xNew = min(max(xNew, minCGap), maxCGap);
        end

        disp("Iteration: " + iteration)
        disp("COST: " + cost)
        %disp("Eta: " + mat2str(eta, 4))
        disp("Grad: " + grad)
        disp("x: "+ x)
        disp("xNew: " + xNew)
        
        % --Update the Gradient--
        if useSurr
            newCost = mean(objectiveFunction(xNew)) * surrogateScaleFactor;
            if newCost <= cost
                disp("GoodCost: " + newCost)
                cost = newCost;
                gradNew = getAnalyticalGradient(xNew, beta_, targetCost);
                x = xNew;
            else
                disp("BadCost: " + newCost)
                gradNew = 0.5 .* getAnalyticalGradient(xNew, beta_, targetCost);
                
            end

        else
            [newCost, ~] = calculate_device_cost(app, xNew, weights, freq_min, freq_max, S_params);

            %[beta_, coVar] = updateBetaRecursive(xNew, newCost, beta_, coVar);
            % Update running best cost
            if newCost <= cost
                cost = newCost;
                gradNew = getDeviceGrad(x, beta_, eta, cost, targetCost, minCGap, span);
                x = xNew;
            else
                %go the other way
                gradNew = -getDeviceGrad(x, beta_, eta, cost, targetCost, minCGap, span); 
                gradNew = gradNew ./ 1.5;
            end
        end

        % Log current state for optimization plotting
        costHistory(iteration) = cost;

        if useSurr
            gaps = getGapsFromC2(x);
            gapHistory(iteration, :) = gaps;
        else
            gapHistory(iteration, :) = x;
        end

        %--------------------------------------------

        if isscalar(gradNew)
            gradNew = repmat(gradNew, 1, 4); 
        else
            gradNew = gradNew(:).';
        end
        
        if variableEta
            deltaPos = xNew - x;
            deltaGrad = gradNew - grad;
            denom = norm(deltaGrad).^2;
            disp("Delta Pos:" + mat2str(deltaPos))
            disp("Delta Grad:" + mat2str(deltaGrad))
            etaNew = abs(deltaPos .* deltaGrad) ./ (denom + 1e-15);
    
            % If an actuator got clipped to limits, its deltaPos is artificially zero.
            % Keep previous learning rate active instead of freezing it.
            if useSurr
                clippedMask = (xNew <= minC) | (xNew >= maxC);
            else
                clippedMask = (xNew <= minCGap) | (xNew >= maxCGap);
            end
    
            etaNew(clippedMask) = eta(clippedMask);
    
            % Apply element-wise limits to each eta
            eta = min(max(etaNew, etaMin), etaMax);
    
            % Slide old rows up, and append the new 1x4 eta vector at the bottom
            etaHistory = [etaHistory(2:3, :); eta];
    
            % Checks if all 4 individual eta channels have remained completely unchanged 
            if all(etaHistory(1, :) == etaHistory(2, :)) && all(etaHistory(2, :) == etaHistory(3, :))
                break;
            end
        end
        grad = gradNew;
    end

    %% Function Results
    if useSurr
        disp("Final X: " + x)
        bestGaps = getGapsFromC2(x);
        disp("FINAL GAPS: " + bestGaps)

        if bestGaps(1) > maxCGap
            fprintf("GAP HAS MAXED OUT")
            bestGaps = maxCGap .* ones(1, length(bestGaps));
        
        elseif bestGaps(1) < minCGap
            fprintf("GAP HAS MINNED OUT")
            bestGaps = minCGap .* ones(1, length(bestGaps));
        end
    else
        bestGaps = x;
    end

    plotOutputMetrics(costHistory, gapHistory, minCGap, maxCGap, targetCost);
    % Send final optimal physical positions to Pico
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), bestGaps);
    writeline(app.pico, cmdToSend);
end


function grad = getDeviceGrad(x, beta_, eta, cost, targetCost, minCGap, span)
    % Directional analytical surrogate gradient guidance normalized, scaled dynamically 
    [~, x_cap] = getDiskCapacitances(x);
    dirGrad = getAnalyticalGradient(x_cap, beta_, targetCost);
    
    % Scaled step magnitude that smoothly decreases on convergence
    errorRatio = max(0.05, min(1.0, (cost - targetCost) / cost));
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

function [bestGaps, maxCGap, minCGap, minOverallCost, worstCost, beta_, coVar, span] = findBestStartPos(app, weights, freq_min, freq_max, S_params, useSurr)
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

    % Plot the pairwise design matrix space
    figure();
    [~, AX, BigAx] = plotmatrix(dCC);
    labels = {'Actuator A', 'Actuator B', 'Actuator C', 'Actuator D'};
    for i = 1:4
        ylabel(AX(i,1), labels{i}, 'FontWeight', 'bold'); 
        xlabel(AX(4,i), labels{i}, 'FontWeight', 'bold'); 
    end
    title(BigAx, 'Pairwise Experimental Space for 4-Actuator Design', 'FontSize', 12);    
    
    % Track the overall optimal configuration
    minOverallCost = inf; 
    bestGaps = midCGap * ones(4,1); 
    bestFreq = [0, 0];
    bestMag = [-inf, -inf]; 
    
    numPoints = length(actuatorPos);

    % Array to store the cost associated with each measurement
    cost_data = zeros(numPoints, 1);

    for row = 1:numPoints
        
        [total_cost, metrics] = calculate_device_cost(app, actuatorPos(row, :), weights, freq_min, freq_max, S_params);
        
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


function grad = getAnalyticalGradient(cap, beta_, targetCost)
    % Compute the current predicted performance Y(x) using clean column operations
    Y_curr = beta_(1) + ...
             sum(beta_(2:5) .* cap) + ...                             % Linear terms (dot product)
             sum(beta_(6:9) .* (cap.^2)) + ...                        % Quadratic terms (dot product)
             beta_(10)*cap(1)*cap(2) + beta_(11)*cap(1)*cap(3) + beta_(12)*cap(1)*cap(4) + ...
             beta_(13)*cap(2)*cap(3) + beta_(14)*cap(2)*cap(4) + ...
             beta_(15)*cap(3)*cap(4);

    % Compute the outer derivative multiplier: 2 * (Y(x) - Y_target)
    outer = 2 * (Y_curr - targetCost);
    
    % Compute the inner partial derivatives dY/dxi
    dY_dx1 = beta_(2) + 2*beta_(6)*cap(1)  + beta_(10)*cap(2) + beta_(11)*cap(3) + beta_(12)*cap(4);
    dY_dx2 = beta_(3) + 2*beta_(7)*cap(2)  + beta_(10)*cap(1) + beta_(13)*cap(3) + beta_(14)*cap(4);
    dY_dx3 = beta_(4) + 2*beta_(8)*cap(3)  + beta_(11)*cap(1) + beta_(13)*cap(2) + beta_(15)*cap(4);
    dY_dx4 = beta_(5) + 2*beta_(9)*cap(4)  + beta_(12)*cap(1) + beta_(14)*cap(2) + beta_(15)*cap(3);

    % Combine to form the final 4x1 gradient column vector
    grad = outer .* [dY_dx1, dY_dx2, dY_dx3, dY_dx4]; %.* 1e-12
end

function [total_cost, metrics] = calculate_device_cost(app, gaps, weight, freq_min, freq_max, S_params)
    % Define Normalization Scaling Targets (Worst acceptable values)
    min_loss_allowed  = -5;     % Obj 1 & 2: Min insertion loss allowed (dB)
    max_freq_drift    = 50e6;  % Obj 3: Max drift from 1.5 GHz (Hz)
    max_s11_allowed   = -10;    % Obj 4: Threshold for return loss (dB)
    maxAmpImbalance   = 5;      % Obj 5: Max dB difference between paths
    wantedPhaseError  = 90;     % Obj 6: Exact phase difference (degrees)
    
    waitForResponse(app);
    cmdToSend = sprintf("%s %d %d %d %d", app.COMMANDS(4), round(gaps));
    writeline(app.pico, cmdToSend);
    
    % Let VNA Stabilize
    pause(1);
    
    % Get VNA data
    [f, S] = readCustomS(app.VNA, S_params);
    
    % Extract peaks in the bandwidth window
    [metrics.freq_21, metrics.mag_21] = find_sparam_peak(f, S(1,:), freq_min, freq_max);
    [metrics.freq_31, metrics.mag_31] = find_sparam_peak(f, S(2,:), freq_min, freq_max);
    [~, curr_11_db]                   = find_sparam_peak(f, S(3,:), freq_min, freq_max); 
    
    % Extract phase properties exactly at 1.5 GHz
    [~, idx_1p5] = min(abs(f - 1.5e9)); 
    phase_21_rad = angle(S(1, idx_1p5));
    phase_31_rad = angle(S(2, idx_1p5));
        
    % Obj S21 & S31 Transmission Cost (Corrected: penalizes if below -5dB)
    cost_obj1 = max(0, abs(min_loss_allowed - metrics.mag_21));
    cost_obj2 = max(0, abs(min_loss_allowed - metrics.mag_31));
    
    % Obj Center Frequency Error (Normalized per-port)
    % Quadratic formulation
    % cost_obj3 = ((abs(metrics.freq_21 - 1.5e9)/max_freq_drift)^2 + ...
    %         (abs(metrics.freq_31 - 1.5e9)/max_freq_drift)^2) / 2;
    % %OLD CODE: 
    cost_obj3 = (abs(metrics.freq_21 - 1.5e9)/max_freq_drift + abs(metrics.freq_31 - 1.5e9)/max_freq_drift) / 2;
    
    % Obj S11 Match Cost 
    cost_obj4 = max(0, curr_11_db - max_s11_allowed) / abs(max_s11_allowed);
    
    % Obj Amplitude Balance
    cost_obj5 = abs(metrics.mag_21 - metrics.mag_31) / maxAmpImbalance;
    
    % Obj Phase Balance (FIXED: Converts rad output of angdiff to degrees)
    phase_diff_deg = rad2deg(abs(angdiff(phase_21_rad, phase_31_rad)));
    cost_obj6  = phase_diff_deg / wantedPhaseError;
    
    %avg_transmission_loss_cost = (cost_obj1 + cost_obj2) / 2;
    total_cost = weight(1)*cost_obj1 + ...
                 weight(2)*cost_obj2 + ...
                 weight(3)*cost_obj3 + ...
                 weight(4)*cost_obj4 + ...
                 weight(5)*cost_obj5 + ...
                 weight(6)*cost_obj6;
end

function [beta_, P] = getBetaConstants(actuatorPos, cost_data)
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

function [beta_new, P_new] = updateBetaRecursive(x_new, cost_new, beta_old, P_old)
    % UPDATEBETARECURSIVE Instantly updates beta parameters using a single new measurement.
    %
    % Inputs:
    %   x_new    : 1 x 4 vector of physical gaps (mm) of the new state
    %   cost_new : Scalar real cost of this new position
    %   beta_old : Current 15x1 beta vector
    %   P_old    : Current 15x15 covariance matrix
    
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


function gaps = getGapsFromC2(C2_values)
    [b, inner_r, wr, e0, ~] = getPhysicalConst();
    C_ring = getRingCap(); % Assuming this returns Farads
    
    numerator_C2 = e0 * pi * inner_r^2 * (b^2 - (inner_r + wr)^2) / b^2;
    
    C2_total_farads = C2_values .* 1e-12;
    C2_isolated = abs(C2_total_farads - C_ring);
    
    gaps = round((numerator_C2 ./ C2_isolated) * 1e6);
    
end

function [C1_total, C2_total] = getDiskCapacitances(gap) 
    gap = gap .* 1e-6;
    [b, inner_r, wr, e0, ~] = getPhysicalConst();
    C_ring = getRingCap();

    % --- Parallel Plate Component ---
    C1 = (e0 * pi * b^2) ./ gap; 
    
    numerator = e0 * pi * inner_r^2 * (b^2 - (inner_r + wr)^2) / b^2;
    C2 = numerator ./ gap;
    
    % --- Combine Systems ---
    % Adding the constant baseline fringing capacitance to the distance-dependent plate term
    C1_total = (C1 + C_ring) .* 1e12;
    C2_total = (C2 + C_ring) .* 1e12;
end

function C_ring = getRingCap()
    [~, inner_r, wr, e0, er] = getPhysicalConst();
    % --- Fringing / Coplanar Component (Bessel Integral) ---
    % Explicitly map 'r' for the integrand to match your math syntax
    r = inner_r; 

    integrand = @(zeta) (besselj(0, zeta.*r) - besselj(0, zeta.*(r + wr))) .* besselj(1, zeta.*r) ./ zeta;

    % Practical integration limit scaling dynamically with ring width
    zeta_max = 50 / wr;   
    integral_value = integral(integrand, 0, zeta_max);

    leading_coeff = (2 * pi * r * e0 * (1 + er)) / log(1 + wr/r);
    C_ring = leading_coeff * integral_value;
end


function maxGap = findMaxGap()
    gap = linspace(1, 4000, 150);
    
    [b, inner_r, wr, e0, ~] = getPhysicalConst();

    [C1_total, C2_total] = getDiskCapacitances(gap);
    C_ring = getRingCap();

    %find kappa (curviest point)
    syms X real % X represents ln(t) because the log domain is being used
    
    % Express t in terms of X: t = exp(X)
    t_expr = exp(X);
    
    % Define C1 and C2 as functions of X
    C1_log_sym = (e0 * pi * b^2) / t_expr + C_ring; 
    C2_log_sym = (e0 * pi * inner_r^2 * (b^2 - (inner_r + wr)^2) / b^2) / t_expr + C_ring;
    
    % Y represents ln(C)
    Y1 = log(C1_log_sym);
    Y2 = log(C2_log_sym);
    
    % --- Log-Log Curve 1 Curvature ---
    v1 = [1, diff(Y1, X)];              % Velocity vector in log space: [dX/dX, dY1/dX]
    T1 = v1 / norm(v1);
    
    dT1 = diff(T1, X);
    k1_sym = norm(dT1) / norm(v1);      % Curvature in log-log space
    
    % --- Log-Log Curve 2 Curvature ---
    v2 = [1, diff(Y2, X)];              % Velocity vector in log space: [dX/dX, dY2/dX]
    T2 = v2 / norm(v2);
    
    dT2 = diff(T2, X);
    k2_sym = norm(dT2) / norm(v2);      % Curvature in log-log space
    
    % --- Numerical Evaluation & Point Finding ---
    % Convert log-space expressions to numerical functions of X
    f_k1 = matlabFunction(k1_sym, 'Vars', X);
    f_k2 = matlabFunction(k2_sym, 'Vars', X);
    
    % Convert your linear distance vector 'd' to log space: X = ln(d)
    X_numerical = log((gap * 1e-6));
    
    % Evaluate log-space curvature over the array
    k1_numerical = f_k1(X_numerical);
    k2_numerical = f_k2(X_numerical);
    
    % Locate the indices of maximum visual curvature (the knees)
    [~, idx1] = max(k1_numerical);
    gap_knee1 = gap(idx1);
    C1_knee1 = C1_total(idx1);
    
    [~, idx2] = max(k2_numerical);
    gap_knee2 = gap(idx2);
    C2_knee2 = C2_total(idx2);

    maxGap = min(gap_knee1, gap_knee2);
 
    % --- Plotting Results ---
    figure();
    loglog(gap, C1_total, 'LineStyle', '-', 'Color', 'r', 'LineWidth', 1.5);
    hold("on");
    loglog(gap, C2_total, 'LineStyle', ':', 'Color', 'b', 'LineWidth', 2);

    % Plot maximum curvature points as solid markers (kappa point)
    loglog(gap_knee1, C1_knee1, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    loglog(gap_knee2, C2_knee2, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');

    xlabel('Distance (\mu m)');
    ylabel('Capacitance (pF)');
    title('Capacitance Over Distance');
    grid("on");
    legend('C1 (Full Disc Plate)', 'C2 (Ring with Fringing Baseline)');
    hold('off');

end

function plotOutputMetrics(costHistory, gapHistory, minCGap, maxCGap, targetCost)

    % --- POST-RUN METRICS PLOT ---
    if ~isempty(costHistory)
        figure('Name', 'Gradient Descent Performance Analysis', 'NumberTitle', 'off', 'Color', 'w');
        
        % Panel 1: Cost Curve Tracking
        subplot(1, 2, 1);
        plot(1:length(costHistory), costHistory, '-o', 'LineWidth', 2, 'Color', [0.85 0.33 0.1]);
        hold on;
        
        yline(targetCost, '--r', sprintf('Target Cost: %.2f', targetCost), ...
              'LineWidth', 1.5, ...
              'LabelHorizontalAlignment', 'left', ...
              'LabelVerticalAlignment', 'bottom');
              
        grid on;
        title('Convergence Path');
        xlabel('Iteration Index');
        ylabel('S-Parameter Objective Cost');
        
        % Panel 2: Physical Gap Actuator Movements
        subplot(1, 2, 2);
        plot(1:size(gapHistory, 1), gapHistory, '-s', 'LineWidth', 1.5);
        grid on;
        title('Hardware Actuator Paths');
        xlabel('Iteration Index');
        ylabel('Gap Spacing (Motor Steps)');
        legend('Disk 1', 'Disk 2', 'Disk 3', 'Disk 4', 'Location', 'best');
        ylim([minCGap - 5, maxCGap + 5]);
    end
end

function [b, inner_r, wr, e0, er] = getPhysicalConst()
    % Dimensions
    b = .01;        % Outer radius 
    inner_r = .003; % Inner radius (This maps to 'r' in your integral formula)
    wr = .0001524;     % Width of the ring

    e0 = 8.854e-12; % Vacuum permittivity (F/m)
    er = 3.7;       % Relative permittivity
end