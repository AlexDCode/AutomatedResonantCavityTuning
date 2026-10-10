function [curr_freq, curr_db] = find_sparam_peak(app, freq_array, s_param_vector, peakType)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Description:
% Finds the minimum or maximum s-param and the associated frequency. 
%
%   Input
%     app            - MATLAB application object
%     freq_array     - Array of frequency data
%     s_param_vector - Array of s-param data
%     peakType       - Determines whether a minimum or maximum is being
%                      searched for
%    
%   Output
%      curr_freq - frequency corresponding to best s-param
%      curr_db  - best chosen s-param
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Ensure everything is a column vector to prevent orientation mismatches
    freq_array = freq_array(:);
    %disp(s_param_vector(:))
    %converts complex value to dB
    s_db = 20 * log10(abs(s_param_vector(:))); % TODO: check that the data being passed is in the right format (linear/complex valued and not in dB already)
    %disp(s_db)
    % The GUI supplies the analysis window in GHz while the VNA axis is in
    % Hz; normalize so the in-band mask compares like units.
    app.fmin = toHz(app.fmin);
    app.fmax = toHz(app.fmax);

    % Identify in-band indices
    in_band = (freq_array >= app.fmin) & (freq_array <= app.fmax);

    % Safety Check: If no points are in-band, return a safe penalty instead
    % of crashing. curr_freq is NaN rather than the window center so a
    % fabricated frequency can never be mistaken for a measured peak.
    if ~any(in_band)
        warning('No frequency points within the [%g, %g] Hz window (sweep spans [%g, %g] Hz). Returning penalty values.', ...
            app.fmin, app.fmax, min(freq_array), max(freq_array));
        curr_freq = NaN;
        curr_db = -100; % Return a harsh but finite penalty
        return;
    end
    
    % Crop search space to in-band only (safely avoids dealing with -inf)
    freq_window = freq_array(in_band);
    s_db_window = s_db(in_band);
    
    % Find max or min
    if strcmp(peakType, 'max')
        [curr_db, idx] = max(s_db_window);
    elseif strcmp(peakType, 'min')
        [curr_db, idx] = min(s_db_window);
    else
        error('peakType must be ''max'' or ''min''.');
    end

    curr_freq = freq_window(idx);
end
