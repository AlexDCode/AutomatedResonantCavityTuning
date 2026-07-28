function fHz = toHz(f)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % DESCRIPTION:
    % The function toHz normalizes a frequency (scalar or array) to Hz.
    % The app's Freq Min / Freq Max fields and center-frequency constants
    % are entered in GHz (0.1 - 20), while the VNA frequency axis is in Hz.
    % Any positive value below 1 MHz cannot be a real Hz frequency for this
    % hardware, so it is interpreted as GHz and scaled by 1e9. Values
    % already in Hz pass through unchanged, so applying this twice is safe.
    %
    % INPUT:
    %   f    - frequency value(s), in Hz or GHz
    %
    % OUTPUT:
    %   fHz  - frequency value(s) in Hz
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fHz = f;
    isGHz = (f > 0) & (f < 1e6);
    fHz(isGHz) = fHz(isGHz) * 1e9;
end
