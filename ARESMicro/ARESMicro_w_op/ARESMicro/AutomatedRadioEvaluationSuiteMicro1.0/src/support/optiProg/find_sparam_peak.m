function [curr_freq, curr_db] = find_sparam_peak(freq_array, s_param_vector, min_bandwidth, max_bandwidth)
    % Ensure everything is a column vector to prevent orientation mismatches
    freq_array = freq_array(:);
    s_db = 20 * log10(abs(s_param_vector(:)));

    % The GUI supplies the analysis window in GHz while the VNA axis is in
    % Hz; normalize so the in-band mask compares like units.
    min_bandwidth = toHz(min_bandwidth);
    max_bandwidth = toHz(max_bandwidth);

    % Identify in-band indices
    in_band = (freq_array >= min_bandwidth) & (freq_array <= max_bandwidth);

    % Safety Check: If no points are in-band, return a safe penalty instead
    % of crashing. curr_freq is NaN rather than the window center so a
    % fabricated frequency can never be mistaken for a measured peak.
    if ~any(in_band)
        warning('No frequency points within the [%g, %g] Hz window (sweep spans [%g, %g] Hz). Returning penalty values.', ...
            min_bandwidth, max_bandwidth, min(freq_array), max(freq_array));
        curr_freq = NaN;
        curr_db = -100; % Return a harsh but finite penalty
        return;
    end
    
    % Crop search space to in-band only (safely avoids dealing with -inf)
    freq_window = freq_array(in_band);
    s_db_window = s_db(in_band);
    
    % Find the peak
    [curr_db, max_idx] = max(s_db_window);
    curr_freq = freq_window(max_idx);
end

% function [curr_freq, curr_db] = find_sparam_peak(freq_array, s_param_vector, min_bandwidth, max_bandwidth)
%     % Flatten the input vector and convert to dB
%     s_db = 20 * log10(abs(squeeze(s_param_vector)));
% 
%     % Zero-out or penalize any data outside the fmin/fmax window
%     out_of_band = (freq_array < min_bandwidth) | (freq_array > max_bandwidth);
%     s_db(out_of_band) = -inf; % Force out-of-band values to -infinity
% 
%     % Use max() to find the absolute peak and its index across the array
%     [curr_db, max_idx] = max(s_db);
% 
%     % Pull the corresponding peak frequency
%     curr_freq = freq_array(max_idx);
% 
%     % Safety Check: If the maximum is still -inf, no valid points were in-band
%     if isinf(curr_db)
%         error('No valid frequency points found within the [%g, %g] window.', fmin, fmax);
%     end
% end