function [b, inner_r, wr, e0, er] = getPhysicalConst()
    % Dimensions
    b = .01;        % Outer radius 
    inner_r = .003; % Inner radius (This maps to 'r' in your integral formula)
    wr = .0001524;     % Width of the ring

    e0 = 8.854e-12; % Vacuum permittivity (F/m)
    er = 3.7;       % Relative permittivity
end