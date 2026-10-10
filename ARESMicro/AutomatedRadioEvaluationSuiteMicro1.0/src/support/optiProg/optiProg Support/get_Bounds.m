function get_Bounds(app, curr_db, curr_freq)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % DESCRIPTION:
    % Check if -10dB point is reached to shorten the sweeping range for sweeping functions.
    %
    % INPUT:
    %   curr_db        - DEF
    %   curr_freq      - DEF
    %   curr_max       - DEF
    %   curr_min       - DEF
    %   peak_freq      - DEF
    %
    % OUTPUT:
    %   fmax           - DEF
    %   fmin           - DEF
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Default: keep the current range (both outputs must be assigned on
    % every path or MATLAB errors with "Output argument not assigned")

    % Check if the -10 dB value is reached
    if curr_db >= -10 && curr_db <= -9.7
        % A -10 dB point below the peak raises the lower bound; one above
        % the peak lowers the upper bound. The window only ever narrows.
        if curr_freq < app.desiredFCenter && curr_freq > app.fmin
            app.fmin = curr_freq;
        elseif curr_freq > app.desiredFCenter && curr_freq < app.fmax
            app.fmax = curr_freq;
        end
    end
end