function gaps = getGapsFromCapacitance(C2_values)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION: 
% Calculates the gap given the individual actuator capacitance. 
%
% INPUT:
%   C2_values -calculated capacitance of actuator
%
% OUTPUT:
%   gaps    -actuator gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [b, inner_r, wr, e0, ~] = getPhysicalConst();
    C_ring = getRingCap(); % Assuming this returns Farads
    
    numerator_C2 = e0 * pi * inner_r^2 * (b^2 - (inner_r + wr)^2) / b^2;
    
    C2_total_farads = C2_values .* 1e-12;
    C2_isolated = abs(C2_total_farads - C_ring);
    
    gaps = round((numerator_C2 ./ C2_isolated) * 1e6);
end