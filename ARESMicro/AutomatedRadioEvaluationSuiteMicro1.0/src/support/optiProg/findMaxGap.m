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
    fig = figure();
    loglog(gap, C1_total, 'LineStyle', '-', 'Color', 'r', 'LineWidth', 4);
    hold("on");
    loglog(gap, C2_total, 'LineStyle', ':', 'Color', 'b', 'LineWidth', 4);

    % Plot maximum curvature points as solid markers (kappa point)
    loglog(gap_knee1, C1_knee1, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    loglog(gap_knee2, C2_knee2, 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    
    center = 349.906;
    xl = xline(center, '--', 'LineWidth', 2);

    xlabel('Distance (\mum)', 'FontSize', 20);
    ylabel('Capacitance (pF)', 'FontSize', 20);
    title('Capacitance Over Distance', 'FontSize', 20);
    grid("off");
    legend('C1 (Full Disc Plate)', 'C2 (Ring with Fringing Baseline)', 'FontSize', 10);
    hold('off');
end