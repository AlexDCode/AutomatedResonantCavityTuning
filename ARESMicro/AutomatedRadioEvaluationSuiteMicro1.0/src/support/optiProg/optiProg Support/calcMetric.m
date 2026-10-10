function [selectedFreq, selectedMag, meanMag] = calcMetric(app, freqs, S_params, condition, sParam)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Description:
% finds the relevant s-parameter magnitude and corresponding frequency 
% as well as the mean magnitude over the frequency range.
% calcMetric = pass the condition, data vector, and min/max freq (BW). return {center freq, max/min value, mean value}
% Table contains the metrics (mag/phase) from calcMetric
%
%   Input
%     app           -MATLAB application object
%     freqs         -Array of frequency data
%     S_params      -Array of s-param data
%     Condition     -User entered condition
%     sParam        -string of s-param for use in tables
%    
%   Output
%      selectedFreq - frequency corresponding to best s-param
%      selectedMag  - best chosen s-param
%      meanMag      - average value of s-param over frequency range
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % --- Restrict evaluation to [app.fmin, app.fmax] ---
    freq_mask = (freqs >= app.fmin) & (freqs <= app.fmax);
    f_band = freqs(freq_mask);
    S_band = S_params(:, freq_mask);

    if strcmp(condition, "=")
         selectedFreq = app.desiredFCenter;
         selectedMag = S_band(sParam, min(abs(selectedFreq - f_band)));
         meanMag = mean(S_band(sParam, :), 'omitnan');
    elseif strcmp(condition, "<")
        [selectedFreq, selectedMag] = find_sparam_peak(app, f_band, S_band(sParam, :), 'max');
        meanMag = mean(S_band(sParam, :), 'omitnan');
    elseif strcmp(condition, ">")
        [selectedFreq, selectedMag] = find_sparam_peak(app, f_band, S_band(sParam, :), 'min');
        meanMag = mean(S_band(sParam, :), 'omitnan');
    elseif strcmp(condition, "None")
        [selectedFreq, selectedMag, meanMag] = deal(NaN, NaN, NaN);
    else
        error("Unknown condition");
    end    
end