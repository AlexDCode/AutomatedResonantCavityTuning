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