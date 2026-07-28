function max_gap = findMaxGap()
    % Constants
    e0 = 8.854e-12; % Vacuum permittivity (F/m)
    er = 3.7;       % Relative permittivity
    
    % Dimensions
    b = .01;        % Outer radius 
    inner_r = .003; % Inner radius (This maps to 'r' in your integral formula)
    wr = .0001524;     % Width of the ring
    d = linspace(1*10^-6, 4000 * 10^-6); % Distance 'g'
    
    % --- Parallel Plate Component ---
    C1 = (e0 * pi * b^2) ./ d; 
    
    numerator = e0 * pi * inner_r^2 * (b^2 - (inner_r + wr)^2) / b^2;
    C2 = numerator ./ d;
    
    % --- Fringing / Coplanar Component (Bessel Integral) ---
    % Explicitly map 'r' for the integrand to match your math syntax
    r = inner_r; 
    
    integrand = @(zeta) (besselj(0, zeta.*r) - besselj(0, zeta.*(r + wr))) .* besselj(1, zeta.*r) ./ zeta;
    
    % Practical integration limit scaling dynamically with ring width
    zeta_max = 50 / wr;   
    integral_value = integral(integrand, 0, zeta_max);
    
    leading_coeff = (2 * pi * r * e0 * (1 + er)) / log(1 + wr/r);
    C_ring = leading_coeff * integral_value;
    
    % --- Combine Systems ---
    % Adding the constant baseline fringing capacitance to the distance-dependent plate term
    C1_total = C1 + C_ring;
    C2_total = C2 + C_ring;
    
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
    X_numerical = log(d);
    
    % Evaluate log-space curvature over the array
    k1_numerical = f_k1(X_numerical);
    k2_numerical = f_k2(X_numerical);
    
    % Locate the indices of maximum visual curvature (the knees)
    [~, idx1] = max(k1_numerical);
    d_knee1 = d(idx1);
    C1_knee1 = C1_total(idx1);
    
    [~, idx2] = max(k2_numerical);
    d_knee2 = d(idx2);
    C2_knee2 = C2_total(idx2);

    max_gap = min(d_knee1, d_knee2);
    
    % --- Plotting Results ---
    figure();
    loglog(d * 10^6, C1_total * 10^12, 'LineStyle', '-', 'Color', 'r', 'LineWidth', 1.5);
    hold("on");
    loglog(d * 10^6, C2_total * 10^12, 'LineStyle', ':', 'Color', 'b', 'LineWidth', 2);
    
    % Plot maximum curvature points as solid markers (kappa point)
    loglog(d_knee1 * 10^6, C1_knee1 * 10^12, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    loglog(d_knee2 * 10^6, C2_knee2 * 10^12, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
    
    xlabel('Distance (\mu m)');
    ylabel('Capacitance (pF)');
    title('Capacitance Over Distance');
    grid("on");
    legend('C1 (Full Disc Plate)', 'C2 (Ring with Fringing Baseline)');
    hold('off');
end