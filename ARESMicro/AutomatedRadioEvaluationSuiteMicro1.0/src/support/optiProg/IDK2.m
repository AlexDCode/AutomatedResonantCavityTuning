%----------------------------
%   --- CONSTANTS ---
%----------------------------
f0 = 1.5 * 1e9;
Zr = 50;
Z0 = 50;
w0 = f0 * 2 * pi;
c = physconst('lightspeed');
e0 = 8.854187817e-12;
die_const = 1; 
h = 1; 
cavity_radius = 1; 
post_radius = 0.2; 
patch_radius = 0.5; 
ring_width = 0.1; 

%----------------------------
%   --- LOOP GAPS ---
%----------------------------
stop_gap = 500e-9;
index_gap = 1e-9;
gap = 0:index_gap:stop_gap; 
num_gaps = length(gap); % Fixed: Get exact size of vector (501 elements)

%----------------------------
%   --- LOOP FREQS ---
%----------------------------
start_freq = 1e9;
stop_freq = 3e9;
% Fixed: Corrected operator precedence using parentheses
index_freq = (stop_freq - start_freq) / (num_gaps - 1); 
w = (start_freq * 2 * pi) : (index_freq * 2 * pi) : (stop_freq * 2 * pi); % Keep in radians/sec
num_freqs = length(w); 

%----------------------------
%   --- CALC CAPACITANCE ---
%----------------------------
C12 = zeros(num_gaps, 1);
for i = 1:num_gaps
    if gap(i) == 0
        C12(i) = Inf; % Avoid division by zero at the first element
    else
        % Fixed: Indexing gap(i) instead of vector gap
        C12(i) = e0 * pi * patch_radius^2 / (cavity_radius^2 * gap(i)) * (cavity_radius^2 - (ring_width + patch_radius)^2);
    end
end

% Fixed: Calling local function correctly passing patch_radius as 'r'
Cring_scalar = calculate_ring_capacitance(patch_radius, ring_width, e0, die_const);
Ceq = Cring_scalar + C12;

%----------------------------
%   --- LOOP INDUCTANCE ---
%----------------------------
Lcav = zeros(num_freqs, 1);
for i = 1:num_freqs
    % Fixed: Changed 'ln' to 'log', and 'tand' to radian-based 'tan'
    Lcav(i) = 60 / (w(i) * sqrt(die_const)) * tan(w(i) * h * sqrt(die_const) / c) * log(cavity_radius / post_radius);
end
%----------------------------
%   --- PLOT RESONANT FREQ GRID ---
%----------------------------
% Fixed: Because Ceq varies with GAP and Lcav varies with FREQUENCY,
% we use a 2D mesh grid to map out the combination space.
[C_grid, L_grid] = meshgrid(Ceq, Lcav);
LC_product = C_grid .* L_grid; 
calculated_w0 = 1 ./ sqrt(LC_product); % w0 = 1/sqrt(LC)

% Plot calculated resonance frequencies across gap array index
figure;
plot(gap * 1e9, calculated_w0(1, :), 'LineWidth', 1.5)
grid on;
xlabel('Gap Distance (nm)')
ylabel('Calculated Resonance \omega_0 (rad/s)')
title('Resonant Frequency Sweep')


%----------------------------
%   --- LOCAL FUNCTION ---
%----------------------------
function Cring = calculate_ring_capacitance(r, wr, eps_0, eps_r)
    leading_term = 2 * pi * r * eps_0 * (1 + eps_r) / log(1 + wr / r);
    integrand = @(z) (besselj(0, z .* r) - besselj(0, z .* (r + wr))) .* ...
                     besselj(1, z .* r) ./ z;
    integral_val = integral(integrand, 0, Inf, 'ArrayValued', true);
    Cring = leading_term * integral_val;
end