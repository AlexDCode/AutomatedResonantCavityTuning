function GradientFunctionPlots()
    bestGap = 59;
    % Parameters & Coefficients
    beta_ = [72.2758 -344.1746 -128.0646  255.1972  334.6974 ...
             -786.5379 -340.9068  449.4004  613.3343 -563.7160 ...
             -168.5691  -86.5957   54.2473  136.2146  531.3661];
    targetCost = 2;
    [~, base_val] = getDiskCapacitances(bestGap);
    
    % Vectorized Objective Function
    obj_func = @(x1, x2, x3, x4) ( ...
            beta_(1) + ...
            beta_(2).*x1 + beta_(3).*x2 + beta_(4).*x3 + beta_(5).*x4 + ...
            beta_(6).*(x1.^2) + beta_(7).*(x2.^2) + ...
            beta_(8).*(x3.^2) + beta_(9).*(x4.^2) + ...
            beta_(10).*x1.*x2 + beta_(11).*x1.*x3 + ...
            beta_(12).*x1.*x4 + beta_(13).*x2.*x3 + ...
            beta_(14).*x2.*x4 + beta_(15).*x3.*x4 ...
            - targetCost ...
        ).^2;
        
    % Plot setup
    range_vec = linspace(1, 226, 50);
    targetCap = 4.8524;
    
    % Define two arbitrary [row, col] pairs to plot
    pairs = [2, 1; 
             3, 2]; 
    
    % Adjusted figure window for 1 row, 2 columns layout
    figure('Position', [100, 100, 1000, 450]);
    
    % Meshgrid generation
    [X_col, X_row] = meshgrid(range_vec, range_vec);
    
    for k = 1:size(pairs, 1)
        row = pairs(k, 1);
        col = pairs(k, 2);
        
        subplot(1, 2, k);
        
        % Hold remaining variables at baseline
        inputs = {base_val, base_val, base_val, base_val};
        inputs{col} = X_col;
        inputs{row} = X_row;
        
        % Evaluate objective
        Y = obj_func(inputs{1}, inputs{2}, inputs{3}, inputs{4});
                     
        % Contour plot
        contourf(X_col, X_row, Y, 15, 'LineColor', 'none');
        colormap(turbo);
        
        % Logarithmic axes
        ax = gca;
        ax.XScale = 'log';
        ax.YScale = 'log';
        hold on;
        
        % --- 1. Target Point (Red Circle) ---
        h1 = plot(targetCap, targetCap, 'ro', ...
            'MarkerSize', 10, 'LineWidth', 2);
            
        % --- 2. Automatic Minimum (Green Circle) ---
        [~, min_linear_idx] = min(Y(:));
        [min_row_idx, min_col_idx] = ind2sub(size(Y), min_linear_idx);
        min_x = X_col(min_row_idx, min_col_idx);
        min_y = X_row(min_row_idx, min_col_idx);
        
        h2 = plot(min_x, min_y, 'go', ...
            'MarkerSize', 10, ...
            'LineWidth', 4, ...
            'MarkerFaceColor', 'g');
        hold off;
        
        title(sprintf('Cap %d vs Cap %d Cost', row, col), 'FontSize', 14);
        xlabel(sprintf('Capacitance %d (pF)', col), 'FontSize', 12);
        ylabel(sprintf('Capacitance %d (pF)', row), 'FontSize', 12);
        grid on;
        
        % Add legend only to first plot
        if k == 1
            legend([h1 h2], {'Target', 'Seen Best Cost'}, ...
                'Location', 'best', 'FontSize', 12);
        end
    end
    
    % Shared colorbar adjusted for 1x2 proportions
    cb = colorbar('Position', [0.92 0.15 0.02 0.72]);
    cb.Label.String = 'Objective Cost';
    cb.FontSize = 14;
    
    sgtitle(sprintf( ...
        'Pairwise Interaction Matrix (Held at Capacitance = %.3fpF)', ...
        base_val), ...
        'FontSize', 20, 'FontWeight', 'bold');
end

% function GradientFunctionPlots()
%     bestGap = 59;
%     % Parameters & Coefficients
%     beta_ = [72.2758 -344.1746 -128.0646  255.1972  334.6974 ...
%              -786.5379 -340.9068  449.4004  613.3343 -563.7160 ...
%              -168.5691  -86.5957   54.2473  136.2146  531.3661];
%     targetCost = 2;
%     [~, base_val] = getDiskCapacitances(bestGap);
% 
%     % Vectorized Objective Function
%     obj_func = @(x1, x2, x3, x4) ( ...
%             beta_(1) + ...
%             beta_(2).*x1 + beta_(3).*x2 + beta_(4).*x3 + beta_(5).*x4 + ...
%             beta_(6).*(x1.^2) + beta_(7).*(x2.^2) + ...
%             beta_(8).*(x3.^2) + beta_(9).*(x4.^2) + ...
%             beta_(10).*x1.*x2 + beta_(11).*x1.*x3 + ...
%             beta_(12).*x1.*x4 + beta_(13).*x2.*x3 + ...
%             beta_(14).*x2.*x4 + beta_(15).*x3.*x4 ...
%             - targetCost ...
%         ).^2;
% 
%     % Plot setup
%     N = 4;
%     range_vec = linspace(1, 226, 50);
%     targetCap = 4.8524;
% 
%     % Adjusted window dimensions for a 2x3 layout (wider aspect ratio)
%     figure('Position', [100, 100, 1200, 700]);
%     sub_idx = 0;
% 
%     % Loop through rows and columns
%     for row = 1:N
%         for col = 1:N
%             if row > col
%                 sub_idx = sub_idx + 1;
% 
%                 % Updated to 2 rows, 3 columns
%                 subplot(2, 3, sub_idx);
% 
%                 % Create meshgrid
%                 [X_col, X_row] = meshgrid(range_vec, range_vec);
% 
%                 % Hold remaining variables at baseline
%                 inputs = {base_val, base_val, base_val, base_val};
%                 inputs{col} = X_col;
%                 inputs{row} = X_row;
% 
%                 % Evaluate objective
%                 Y = obj_func(inputs{1}, inputs{2}, ...
%                              inputs{3}, inputs{4});
% 
%                 % Contour plot
%                 contourf(X_col, X_row, Y, 15, ...
%                          'LineColor', 'none');
%                 colormap(turbo);
% 
%                 % Logarithmic axes
%                 ax = gca;
%                 ax.XScale = 'log';
%                 ax.YScale = 'log';
%                 hold on;
% 
%                 % --- 1. Target Point (Red Circle) ---
%                 h1 = plot(targetCap, targetCap, ...
%                     'ro', 'MarkerSize', 10, ...
%                     'LineWidth', 2);
% 
%                 % --- 2. Automatic Minimum (Green Circle) ---
%                 [~, min_linear_idx] = min(Y(:));
%                 [min_row_idx, min_col_idx] = ...
%                     ind2sub(size(Y), min_linear_idx);
%                 min_x = X_col(min_row_idx, min_col_idx);
%                 min_y = X_row(min_row_idx, min_col_idx);
%                 h2 = plot(min_x, min_y, ...
%                     'go', 'MarkerSize', 10, ...
%                     'LineWidth', 4, ...
%                     'MarkerFaceColor', 'g');
%                 hold off;
% 
%                 title(sprintf('Cap %d vs Cap %d Cost', row, col), ...
%                     'FontSize', 15);
%                 xlabel(sprintf('Capacitance %d (pF)', col), ...
%                     'FontSize', 15);
%                 ylabel(sprintf('Capacitance %d (pF)', row), ...
%                     'FontSize', 15);
%                 grid on;
% 
%                 % Add legend only to first subplot
%                 if sub_idx == 1
%                     legend([h1 h2], ...
%                         {'Target', 'Seen Best Cost'}, ...
%                         'Location', 'best', FontSize=15);
%                 end
%             end
%         end
%     end
% 
%     % Global colorbar adjusted slightly for the 2x3 proportions
%     cb = colorbar('Position', [0.92 0.11 0.02 0.78]);
%     cb.Label.String = 'Objective Cost';
%     cb.FontSize = 20;
%     sgtitle(sprintf( ...
%         'Pairwise Interaction Matrix (Held at Capacitance = %.3fpF)', ...
%         base_val), ...
%         'FontSize', 20, 'FontWeight', 'bold');
% end


% function GradientFunctionPlots()
%     bestGap = 59;
% 
%     % Parameters & Coefficients
%     beta_ = [72.2758 -344.1746 -128.0646  255.1972  334.6974 ...
%              -786.5379 -340.9068  449.4004  613.3343 -563.7160 ...
%              -168.5691  -86.5957   54.2473  136.2146  531.3661];
% 
%     targetCost = 2;
%     [~, base_val] = getDiskCapacitances(bestGap);
% 
%     % Landed gap/capacitance values
%     % L = [6.2414, 4.9927, 6.3999, 4.7162];
%     % L = [7.2029 5.1978 7.6634 4.0536];
% 
%     % Vectorized Objective Function
%     obj_func = @(x1, x2, x3, x4) ( ...
%             beta_(1) + ...
%             beta_(2).*x1 + beta_(3).*x2 + beta_(4).*x3 + beta_(5).*x4 + ...
%             beta_(6).*(x1.^2) + beta_(7).*(x2.^2) + ...
%             beta_(8).*(x3.^2) + beta_(9).*(x4.^2) + ...
%             beta_(10).*x1.*x2 + beta_(11).*x1.*x3 + ...
%             beta_(12).*x1.*x4 + beta_(13).*x2.*x3 + ...
%             beta_(14).*x2.*x4 + beta_(15).*x3.*x4 ...
%             - targetCost ...
%         ).^2;
% 
%     % Plot setup
%     N = 4;
%     range_vec = linspace(1, 226, 50);
%     targetCap = 4.8524;
% 
%     figure('Position', [100, 50, 750, 850]);
% 
%     sub_idx = 0;
% 
%     % Loop through rows and columns
%     for row = 1:N
%         for col = 1:N
%             if row > col
%                 sub_idx = sub_idx + 1;
% 
%                 subplot(3, 2, sub_idx);
% 
%                 % Create meshgrid
%                 [X_col, X_row] = meshgrid(range_vec, range_vec);
% 
%                 % Hold remaining variables at baseline
%                 inputs = {base_val, base_val, base_val, base_val};
%                 inputs{col} = X_col;
%                 inputs{row} = X_row;
% 
%                 % Evaluate objective
%                 Y = obj_func(inputs{1}, inputs{2}, ...
%                              inputs{3}, inputs{4});
% 
%                 % Contour plot
%                 contourf(X_col, X_row, Y, 15, ...
%                          'LineColor', 'none');
%                 colormap(turbo);
% 
%                 % Logarithmic axes
%                 ax = gca;
%                 ax.XScale = 'log';
%                 ax.YScale = 'log';
% 
%                 hold on;
% 
%                 % --- 1. Target Point (Red Circle) ---
%                 h1 = plot(targetCap, targetCap, ...
%                     'ro', 'MarkerSize', 10, ...
%                     'LineWidth', 2);
% 
%                 % --- 2. Automatic Minimum (Green Circle) ---
%                 [~, min_linear_idx] = min(Y(:));
%                 [min_row_idx, min_col_idx] = ...
%                     ind2sub(size(Y), min_linear_idx);
% 
%                 min_x = X_col(min_row_idx, min_col_idx);
%                 min_y = X_row(min_row_idx, min_col_idx);
% 
%                 h2 = plot(min_x, min_y, ...
%                     'go', 'MarkerSize', 10, ...
%                     'LineWidth', 4, ...
%                     'MarkerFaceColor', 'g');
% 
%                 % % --- 3. Landed Values (Blue Square) ---
%                 % h3 = plot(L(col), L(row), ...
%                 %     'bs', ...
%                 %     'MarkerSize', 10, ...
%                 %     'LineWidth', 2, ...
%                 %     'MarkerFaceColor', 'b');
% 
%                 hold off;
% 
%                 title(sprintf('Cap %d vs Cap %d Cost', row, col), ...
%                     'FontSize', 20);
% 
%                 xlabel(sprintf('Capacitance %d (pF)', col), ...
%                     'FontSize', 15);
% 
%                 ylabel(sprintf('Capacitance %d (pF)', row), ...
%                     'FontSize', 15);
% 
%                 grid on;
% 
%                 % Add legend only to first subplot
%                 if sub_idx == 1
%                     legend([h1 h2], ...
%                         {'Target', 'Percieved Minimum Cost', 'L Solution'}, ...
%                         'Location', 'best');
%                 end
%             end
%         end
%     end
% 
%     % Global colorbar
%     cb = colorbar('Position', [0.91 0.11 0.025 0.78]);
%     cb.Label.String = 'Objective Cost';
% 
%     sgtitle(sprintf( ...
%         'Pairwise Interaction Matrix (Held at Capacitance = %.3fpF)', ...
%         base_val), ...
%         'FontSize', 20, 'FontWeight', 'bold');
% end

function [C1_total, C2_total] = getDiskCapacitances(gap) 
    gap = gap .* 1e-6;
    [b, inner_r, wr, e0, ~] = getPhysicalConst();

    % --- Parallel Plate Component ---
    C1 = (e0 * pi * b^2) ./ gap; 
    
    numerator = e0 * pi * inner_r^2 * (b^2 - (inner_r + wr)^2) / b^2;
    C2 = numerator ./ gap;
    
    C_ring = getRingCap();

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

function [b, inner_r, wr, e0, er] = getPhysicalConst()
    % Dimensions
    b = .01;        % Outer radius 
    inner_r = .003; % Inner radius (This maps to 'r' in your integral formula)
    wr = .0001524;     % Width of the ring

    e0 = 8.854e-12; % Vacuum permittivity (F/m)
    er = 3.7;       % Relative permittivity
end