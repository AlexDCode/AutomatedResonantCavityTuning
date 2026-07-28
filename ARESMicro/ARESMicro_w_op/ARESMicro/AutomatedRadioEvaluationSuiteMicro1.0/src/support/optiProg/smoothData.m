function [y1_warped, y2_warped, R_after] = smoothData(y1, y2)

    %% Pre-process: Smooth out local variations/noise
    % This leaves just the macro-shape before we try to match them
    windowSize = 15;
    y1_smooth = smoothdata(y1, 'gaussian', windowSize);
    y2_smooth = smoothdata(y2, 'gaussian', windowSize);
    
    %% Apply Dynamic Time Warping (DTW)
    % We restrict the warping window to prevent unphysical over-stretching
    maxWindow = 30; 
    [dtw_dist, ix, iy] = dtw(y1_smooth, y2_smooth, maxWindow);
    
    y1_warped = y1_smooth(ix);
    y2_warped = y2_smooth(iy);
    
    % Calculate standard correlation BEFORE and AFTER alignment for comparison
    R_before = corrcoef(y1, y2);
    R_after  = corrcoef(y1_warped, y2_warped);
    
    %% 4. Visualize the Results
    figure('Position', [100, 100, 1000, 450]);

    % Plot 1: Original noisy, stretched data
    subplot(1, 2, 1);
    plot(x, y1, 'LineWidth', 1.5, 'DisplayName', 'Curve 1 (Original)');
    hold on;
    plot(x, y2, 'LineWidth', 1.5, 'DisplayName', 'Curve 2 (Stretched + Varied)');
    grid on;
    title(sprintf('Original Data (Raw Corr: %.2f)', R_before(1,2)));
    xlabel('X-axis'); ylabel('Amplitude');
    legend('Location', 'southwest');

    % Plot 2: DTW alignment of the smoothed shapes
    subplot(1, 2, 2);
    dtw(y1_smooth, y2_smooth, maxWindow);
    title(sprintf('DTW Alignment on Smoothed Shapes (Shape Corr: %.2f)', R_after(1,2)));
    xlabel('Curve 1 Index'); ylabel('Curve 2 Index');

    % Display distance metric in the command window
    fprintf('--- Shape Matching Results ---\n');
    fprintf('Raw Pearson Correlation: %.3f\n', R_before(1,2));
    fprintf('DTW Shape Distance:       %.3f (Lower = closer shape)\n', dtw_dist);
    fprintf('Aligned Shape Correlation: %.3f\n', R_after(1,2));
end