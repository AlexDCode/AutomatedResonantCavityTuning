function plotOutputMetrics(app)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% Primarily used for gradient descent or optimization alorithms. This
% function plots the cost and actuator gap history.
%
% INPUT:
%   app            - MATLAB application object
%
% OUTPUT:
%   void
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % --- POST-RUN METRICS PLOT ---
    if ~isempty(app.costHistory)
        figure('Name', 'Gradient Descent Performance Analysis', 'NumberTitle', 'off', 'Color', 'w');
        
        % Panel 1: app.cost Curve Tracking
        subplot(1, 2, 1);
        plot(1:length(app.costHistory), app.costHistory, '-o', 'LineWidth', 2, 'Color', [0.85 0.33 0.1]);
        hold on;
        
        yline(app.targetapp.cost, '--r', sprintf('Target app.cost: %.2f', app.targetapp.cost), ...
              'LineWidth', 1.5, ...
              'LabelHorizontalAlignment', 'left', ...
              'LabelVerticalAlignment', 'bottom');
              
        grid on;
        title('Convergence Path');
        xlabel('Iteration Index');
        ylabel('S-Parameter Objective app.cost');
        
        % Panel 2: Physical Gap Actuator Movements
        subplot(1, 2, 2);
        plot(1:size(app.gapHistory, 1), app.gapHistory, '-s', 'LineWidth', 1.5);
        grid on;
        title('Hardware Actuator Paths');
        xlabel('Iteration Index');
        ylabel('Gap Spacing (Motor Steps)');
        legend('Disk 1', 'Disk 2', 'Disk 3', 'Disk 4', 'Location', 'best');
        ylim([app.minCGap - 5, app.maxCGap + 5]);
    end
end