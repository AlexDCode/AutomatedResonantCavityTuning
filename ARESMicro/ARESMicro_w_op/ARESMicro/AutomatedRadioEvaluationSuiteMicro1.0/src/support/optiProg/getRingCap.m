function C_ring = getRingCap()
    [~, inner_r, wr, e0, er] = getPhysicalConst();
    % --- Fringing / Coplanar Component (Bessel Integral) ---
    % Explicitly map 'r' for the integrand to match your math syntax
    r = inner_r; 
    
    integrand = @(zeta) (besselj(0, zeta.*r) - besselj(0, zeta.*(r + wr))) .* besselj(1, zeta.*r) ./ zeta;
    
    % Practical integration limit scaling dynamically with ring width
    zeta_max = 50 / wr;   
    integral_value = integral(integrand, 0, zeta_max);
    
    leading_coeff = (2 * pi * r * e0 * (1 + er)) / log(1 + wr/r);
    C_ring = leading_coeff * integral_value;
end
