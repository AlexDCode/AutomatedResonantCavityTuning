%% 1. Load the Touchstone .s4p File
filename = ['C:\Users\skrdl\OneDrive - purdue.edu\SURF\DATA\SURF Research\LIVED1.s4p']; % Replace with your file path
s_data = sparameters(filename);
center_freq = 1.73;
axisMin = 1.5;
axisMax = 1.9;
% Extract frequencies and S-parameter matrix
freq = s_data.Frequencies; % In Hz
s_matrix = s_data.Parameters; % 4x4xN complex double array

% %% 2. Plot All 16 S-Parameters (dB vs. Frequency)
% figure('Name', 'All 16 S-Parameters', 'NumberTitle', 'off');
% rfplot(s_data); 
% grid on;
% title('Complete 4-Port S-Parameter Matrix');

%% 3. Plot Transmission & Reflection from Port 1 (Custom Plot)
figure('Name', 'Port 1 Responses', 'NumberTitle', 'off');

% Extract dB values manually for precise control
s11_db = 20*log10(abs(squeeze(s_matrix(1, 1, :))));
s21_db = 20*log10(abs(squeeze(s_matrix(2, 1, :))));
s31_db = 20*log10(abs(squeeze(s_matrix(3, 1, :))));
s41_db = 20*log10(abs(squeeze(s_matrix(4, 1, :))));

% --- Plot your data ---
plot(freq/1e9, s11_db, 'LineWidth', 4, 'DisplayName', 'S11 (Return Loss)');
hold on;
plot(freq/1e9, s21_db, 'LineWidth', 4, 'DisplayName', 'S21 (Thru)');
plot(freq/1e9, s31_db, 'LineWidth', 4, 'DisplayName', 'S31 (Coupled)');
plot(freq/1e9, s41_db, 'LineWidth', 4, 'DisplayName', 'S41 (Isolation)');
hold off;

% --- Custom X-Axis Setup ---
ax = gca;
ax.XColor = 'none'; % Erase the standard continuous x-axis line & default ticks

ax.YColor = 'k';
ax.LineWidth = 2;                    % Thick main axis line
ax.FontSize = 15;                    % Y-tick numbers font size
ax.TickLength = [0.02 0.02];         % Longer tick marks

% Get current y-bounds to draw the custom axis right at the bottom edge
yLimits = ylim;
yMin = yLimits(1);
tickHeight = (yLimits(2) - yLimits(1)) * 0.02; % Small tick mark height

% 1. Draw axis segment between 1.5 GHz and 2 GHz
line([axisMin, axisMax], [yMin, yMin], 'Color', 'k', 'LineWidth', 4, 'HandleVisibility', 'off');

% 2. Draw tick marks at 1.5, 1.75, and 2 GHz
ticks = [axisMin, center_freq ,axisMax];
for t = ticks
    line([t, t], [yMin, yMin + tickHeight], 'Color', 'k', 'LineWidth', 2, 'HandleVisibility', 'off');
    text(t, yMin - tickHeight, sprintf('%.2f', t), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 14);
end

% Label placed below the center of the customized axis segment
% text(center_freq, yMin - 3.5 * tickHeight, 'Frequency (GHz)', ...
%      'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontWeight', 'bold');

xl = xline(center_freq, '--', 'DisplayName', sprintf('f_0 = %.2f GHz', center_freq), 'LineWidth', 2);

% (Optional) Push the lines behind the S-parameter curves so they don't cut over them
uistack(xl, 'bottom');

grid off;
xl = xlabel('Frequency (GHz)', 'FontSize', 20);
xl.Color = 'k';
ylabel('Magnitude (dB)', 'FontSize', 20);
title('S-Parameters For AGD', 'FontSize', 20);
legend('Location', 'best', 'FontSize', 15);

%% 4. Measure and Plot Phase Imbalance (Port 2 vs. Port 3)
figure('Name', 'Phase Imbalance', 'NumberTitle', 'off');

% Extract raw complex S-parameters for Phase calculation
s21_complex = squeeze(s_matrix(2, 1, :));
s31_complex = squeeze(s_matrix(3, 1, :));

% 1. Compute Unwrapped Phase in Degrees
phase21_deg = rad2deg(unwrap(angle(s21_complex)));
phase31_deg = rad2deg(unwrap(angle(s31_complex)));

% 2. Calculate Actual Phase Difference
phase_diff = phase21_deg - phase31_deg;

% 3. Compute Phase Imbalance
% ADJUST nominal_phase_shift to match your design target:
%   0 for in-phase power divider (Wilkinson), 90 for quadrature coupler, 180 for balun
nominal_phase_shift = 90; 
phase_imbalance = phase_diff - nominal_phase_shift;

% 4. Print Summary Metrics for 1.5 - 2.0 GHz Band
freq_ghz = freq / 1e9;
idx_range = (freq_ghz >= 1.5) & (freq_ghz <= 2.0);
imbalance_sub = phase_imbalance(idx_range);

% 5. Plot Phase Imbalance Curve
plot(freq_ghz, phase_imbalance, 'LineWidth', 4, 'DisplayName', 'Phase Imbalance');

% Apply custom X-Axis matching your styling
ax2 = gca;
ax2.XColor = 'none';
ax2.FontSize = 15;
ax2.YColor = 'k';
ax2.LineWidth = 2;                    % Thick main axis line
ax2.FontSize = 15;                    % Y-tick numbers font size
ax2.TickLength = [0.02 0.02];         % Longer tick marks

yLimits2 = ylim;
yMin2 = yLimits2(1);
tickHeight2 = (yLimits2(2) - yLimits2(1)) * 0.02;

line([axisMin, axisMax], [yMin2, yMin2],'Color', 'k', 'LineWidth', 4, 'HandleVisibility', 'off');

for t = ticks
    line([t, t], [yMin2, yMin2 + tickHeight2], 'Color', 'k', 'LineWidth', 2, 'HandleVisibility', 'off');
    text(t, yMin2 - tickHeight2, sprintf('%.2f', t), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 14);
end

% text(center_freq, yMin2 - 3.5 * tickHeight2, 'Frequency (GHz)', ...
%     'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontWeight', 'bold');

xl = xline(center_freq, '--', 'DisplayName', sprintf('f_0 = %.2f GHz', center_freq), 'LineWidth', 2);

% (Optional) Push the lines behind the S-parameter curves so they don't cut over them
uistack(xl, 'bottom');

ylabel('Phase Imbalance (deg)', 'FontSize', 20);
xl = xlabel('Frequency (GHz)', 'FontSize', 20);
xl.Color = 'k';
title('Phase Imbalance (S21 - S31)', 'FontSize', 20);
grid off;
legend('Location', 'best');

% %% 5. Plot Input Match (S11) on a Smith Chart
% figure('Name', 'S11 Smith Chart', 'NumberTitle', 'off');
% smithplot(s_data, 1, 1);
% title('Port 1 Input Impedance (S11)');







% %% 1. Define File Paths & Setup
% %% 1. Define File Paths & Setup
% filenames = { ...
%     'C:\Users\skrdl\OneDrive - purdue.edu\SURF\DATA\SURF Research\Baseline2.s4p', ...
%     'C:\Users\skrdl\OneDrive - purdue.edu\SURF\DATA\SURF Research\Basic2.s4p', ...
%     'C:\Users\skrdl\OneDrive - purdue.edu\SURF\DATA\SURF Research\2D3.s4p', ...
%     'C:\Users\skrdl\OneDrive - purdue.edu\SURF\DATA\SURF Research\LIVED1.s4p', ...
%     'C:\Users\skrdl\OneDrive - purdue.edu\SURF\DATA\SURF Research\SURR3.s4p' ...
% };
% labels = {'Baseline2', 'Basic2', '2D2', 'LIVED1', 'SURR3'};
% nominal_phase_shift = 90; % Target phase offset (0 = Wilkinson, 90 = Quadrature, 180 = Balun)
% 
% %% 2. Create Figure Window
% figure('Name', 'Design Comparison: Magnitude'); % Balanced width/height for a 3x2 grid
% 
% %% 3. Loop Through Each File and Create Subplots
% for i = 1:length(filenames)
%     % Load Touchstone Data
%     s_data = sparameters(filenames{i});
%     raw_freq_ghz = s_data.Frequencies / 1e9;
% 
%     % Logical Mask for Frequency Range (1 to 2 GHz as requested earlier)
%     mask = (raw_freq_ghz > 1) & (raw_freq_ghz < 2);
%     freq_ghz = raw_freq_ghz(mask);
% 
%     s_matrix = s_data.Parameters;
% 
%     % Extract complex vectors using mask
%     s21_complex = squeeze(s_matrix(2, 1, mask));
%     s31_complex = squeeze(s_matrix(3, 1, mask));
%     s11_complex = squeeze(s_matrix(1, 1, mask));
%     s41_complex = squeeze(s_matrix(4, 1, mask));
% 
%     % 1. Compute Magnitude (dB)
%     s21_db = 20 * log10(abs(s21_complex));
%     s31_db = 20 * log10(abs(s31_complex));
%     s11_db = 20 * log10(abs(s11_complex));
%     s41_db = 20 * log10(abs(s41_complex));
% 
%     % 2. Compute Phase Difference & Imbalance
%     phase21_deg = rad2deg(unwrap(angle(s21_complex)));
%     phase31_deg = rad2deg(unwrap(angle(s31_complex)));
%     phase_diff  = phase21_deg - phase31_deg;
%     phase_imbalance = phase_diff - nominal_phase_shift;
% 
%     % Select subplot panel (3 rows, 2 columns)
%     ax = subplot(3, 2, i);
% 
%     % --- Magnitude Plot (dB) ---
%     plot(ax, freq_ghz, s21_db, 'LineWidth', 1.5, 'Color', 'y');
%     hold(ax, "on");
%     plot(ax, freq_ghz, s31_db, 'LineWidth', 1.5, 'Color', 'r');
%     plot(ax, freq_ghz, s11_db, 'LineWidth', 1.5, 'Color', 'b');
%     plot(ax, freq_ghz, s41_db, 'LineWidth', 1.5, 'Color', 'g');
%     ylabel(ax, 'Mag (dB)');
%     hold(ax, "off");
% 
%     % Subplot Formatting
%     title(ax, sprintf('Design %d: %s', i, labels{i}), 'FontWeight', 'bold');
%     grid(ax, 'on');
%     pbaspect(ax, [1 1 1]); % Keep aspect ratio 1:1 square inside grid cell
% 
%     xlim(ax, [min(freq_ghz), max(freq_ghz)]);
% 
%     % Add X-label on bottom subplots (4 and 5 in a 3x2 grid)
%     if i >= 4
%         xlabel(ax, 'Frequency (GHz)', 'FontWeight', 'bold');
%     end
% end