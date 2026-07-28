%----------------------------
%   --- CONSTANTS ---
%----------------------------
Q = 400;
f0 = 1.5 * 1e9;
Zr = 50;
Z0 = 50;
w0 = f0 * 2 * pi;
c = physconst('lightspeed');
e0 = 8.854187817e-12;

die_const = 3.27; %<--temp
h = 5.08 * 10^-3; %<-temp
cavity_radius = 10*10^-3; %<-temp
post_radius = 1*10^-3; %<-temp
patch_radius = 2 * 10^-3; %<-temp
ring_width = 0.2*10^-3; %<-temp

R = Q * Zr;
n = 0.052;
FBW = 0.03;

%----------------------------
%   --- INPUT SIGNAL ---
%----------------------------
%p1 = sin();

%----------------------------
%   --- LOOP GAPS & FREQS---
%----------------------------
num_points = 500;

stop_gap = 100000e-6;
start_gap = 1e-6;
gaps = linspace(start_gap, stop_gap, num_points);

start_freq = 1e9;
stop_freq = 3e9;
freqs = linspace(start_freq, stop_freq, num_points);
w = freqs * 2 * pi;

%----------------------------
%   --- CALC CAPACITANCE ---
%  Iterates through gap values
%----------------------------
C12 = zeros(num_points, 1);
for i = 1:num_points
    C12(i) = (e0 * pi * patch_radius^2) / (gaps(i) * cavity_radius^2) * (cavity_radius^2 - (ring_width + patch_radius)^2);
end

Ceq = calculate_ring_capacitance(ring_width, patch_radius, e0, die_const) + C12;

%----------------------------
%   --- LOOP INDUCTANCE ---
% Iterates through w values
%----------------------------
Lcav = zeros(num_points, 1);
for i = 1:num_points
    Lcav(i) = (60 / (w(i) * sqrt(die_const))) * ...
              tan(w(i) * h * sqrt(die_const) / c) * ...
              log(cavity_radius / post_radius);
end

% %----------------------------
% %   --- PLOTTING ---
% %----------------------------
% figure;
% % loglog(gaps * 10e6, Ceq * 10e12, 'LineWidth', 1.5)
% % xlabel('Gaps (um)');
% % ylabel('Ceq (pF)');
% 
% % center_freq_calc = 1 ./ sqrt(Ceq .* Lcav);
% % loglog(gaps * 10e6, center_freq_calc * 10e-9, 'LineWidth', 1.5)
% % xlabel('Gaps (um)');
% % ylabel('Freq (GHz)');
% grid on;

%----------------------------
%   --- COMPONENTS ---
%----------------------------

%We now have L and C!
% Find J-inverter value (it is a tee)
% J is proportional to K * w * C

% 1 -> [Je] --- [Y] --- [J121] --- [Y] --- [Je] -> 2
%                |                  |
%               [J122]            [J122]
%                |                  |
% 4 <- [Je] --- [Y] --- [J121] --- [Y] --- [Je] -> 3

J121 = 1/(w * Lcav);
J122 = J121;

ke = sqrt(n); %[[0, -1i * Je], [-1i / Je, 0]];
k121 = sqrt(2) * n; %[[0, -1i * J121], [-1i / J121, 0]];
k122 = n; %[[0, -1i * J122], [-1i / J122, 0]];

% J122 = k122/sqrt(Z0 * Zr);
% %J121 = k121/sqrt(Z0 * Zr);
% Je = ke / sqrt(Z0*Zr);

Ve = 1i * J122;
adm_odd = 1i / (2*Zr) * (FBW * (FBW + 2)) / (FBW + 4) + 1/R - Ve;
adm_eve = 1i / (2*Zr) * (FBW * (FBW + 2)) / (FBW + 4) + 1/R + Ve;

%==========================

%-----METHOD TO CHECK FORM----
% syms tYe tYo tj121 tj122 tje; %tKe tK121 tK122 tadm_odd tadm_eve tABCDo tABCDe;
% 
% tke = [0, -1i / tje; -1i * tje, 0];
% tK121 = [0, -1i / tj121; -1i * tj121, 0];
% tK122 = [0, -1i / tj122; -1i * tj122, 0];
% tadm_odd = [1, 0; tYo, 1];
% tadm_eve = [1, 0; tYo, 1]; 
% 
% tABCDo = tke * tadm_odd * tK121 * tadm_odd * tke;
% tABCDe = tke * tadm_eve * tK121 * tadm_eve * tke;
% disp(tABCDo)
% disp(tABCDe)

% 
% ABCDe = 1i / J121 * [Ye, Je.^2; (Ye.^2 + J121.^2) / Je.^2, Ye];
% 
% ABCDo = 1i / J121 * [Yo, Je.^2; (Yo.^2 + J121.^2) / Je.^2, Yo];

% Create J-inverter ans S-parameter matrices
Ke = [0, -1i / Je; -1i * Je, 0];
K121 = [0, -1i / J121; -1i * J121, 0];
K122 = [0, -1i / J122; -1i * J122, 0];
Y_eve = [1, adm_eve; 0, 1]; 
Y_odd = [1, adm_odd; 0, 1];

%Obtain the Systems ABCD matrix
ABCDe = ke * Y_eve * K121 * Y_eve * ke;
ABCDo = ke * Y_odd * K121 * Y_odd * ke;

%Calculate Transmission and Reflection Coeff.
gammae = (ABCDe(1) - ABCDe(4) + (ABCDe(3)/Z0 - ABCDe(2)*Z0)) ...
         / (ABCDe(1) + ABCDe(4) + ABCDe(3) / Z0 + ABCDe(2) * Z0);

gammao = (ABCDo(1) - ABCDo(4) + (ABCDo(3)/Z0 - ABCDo(2)*Z0)) ...
         / (ABCDo(1) + ABCDo(4) + ABCDo(3) / Z0 + ABCDo(2) * Z0);

transe = 2 / (ABCDe(1) + ABCDe(4) + ABCDe(3)/Z0 + ABCDe(2) * Z0);
transo = 2 / (ABCDo(1) + ABCDo(4) + ABCDo(3)/Z0 + ABCDo(2) * Z0);


s_matrix = zeros(4, 4, num_points);
for i = 1:num_points
    
    % Step A: Construct the temporary lower-triangular matrix for point 'i'
    S_temp = 1/2 * [
        (gammae(i) + gammao(i)), 0,                      0,                      0;
        (transe(i) + transo(i)), (gammae(i) + gammao(i)), 0,                      0;
        (transe(i) - transo(i)), (gammae(i) - gammao(i)), (gammae(i) + gammao(i)), 0;
        (gammae(i) - gammao(i)), (transe(i) - transo(i)), (transe(i) + transo(i)), (gammae(i) + gammao(i))  
    ];
    
    % Step B: Mirror the strictly lower triangle to the upper triangle 
    % and store it in the i-th slice of the 3D matrix
    s_matrix(:,:,i) = tril(S_temp, -1).' + S_temp;
    
end



%----------------------------
%   --- PLOTTING ---
%----------------------------
figure;
% 1. Extract the (1,1) position across ALL frequencies and flatten it
s11_linear = squeeze(s_matrix(4, 1, :));

% 2. Convert the linear magnitude to decibels (dB)
s11_dB = 20 * log10(abs(s11_linear));

% 3. Plot using freqs on the x-axis (Note: divide freqs by 1e9 if your xlabel is GHz)
plot(freqs / 1e9, s11_dB, 'LineWidth', 1.5)

xlabel('Freq (GHz)');
ylabel('S_{11} (dB)');
grid on;


function Cring = calculate_ring_capacitance(r, wr, eps_0, eps_r)
    % Calculates the ring capacitance Cring based on the analytical formula.
    %
    % Inputs:
    %   r     - Patch radius
    %   wr    - Ring width
    %   eps_0 - Permittivity of free space (e.g., 8.854e-12 F/m)
    %   eps_r - Relative permittivity of the substrate
    %
    % Output:
    %   Cring - Calculated ring capacitance

    % Compute the analytical leading term outside the integral
    leading_term = 2 * pi * r * eps_0 * (1 + eps_r) / log(1 + wr / r);
    
    % Define the integrand as an anonymous function of zeta (z)
    % We use besselj(n, x) for the nth-order Bessel function of the first kind.
    % 'ArrayValued', true is paired with this to handle vectorized evaluation.
    integrand = @(z) (besselj(0, z .* r) - besselj(0, z .* (r + wr))) .* ...
                     besselj(1, z .* r) ./ z;
                 
    % Evaluate the integral from 0 to Infinity
    % Note: At z = 0, the analytical limit of the integrand is 0, 
    % but numerically it can hit 0/0. We start slightly above 0 (e.g., eps)
    % or let MATLAB's global adaptive quadrature handle the singularity.
    integral_val = integral(integrand, eps, 1e6, 'ArrayValued', true);
    
    % Multiply the leading coefficient by the integral result
    Cring = leading_term * integral_val;
end



% % %%function run_mpc...
% % %get results and gaps
% % 
% % %----------------
% % %   sweep data 
% % %----------------
% % % starting_gaps = [0, 0, 0, 0];
% % % S_params = {
% % %     S11, S12, S13, S14;
% % %     S21, S22, S23, S24;
% % %     S31, S32, S33, S34;
% % %     S41, S42, S43, S44
% % % };
% % 
% % %----------------
% % %   get model 
% % %----------------
% % starting_gaps = [10, 20, 30, 40]; 
% % Ts = 0.1; % Ensure Ts is defined
% % 
% % % --- Test Non-linear Model Setup ---
% % nonlinear_model = @(x) -(x.^2 + x);
% % 
% % % --- Analytical Derivative (Linearization) ---
% % % The derivative of x^2 + x is 2*x + 1. 
% % % This calculates the exact local slope for each of your 4 gaps.
% % derivative_model = @(x) -(2.*x + 1);
% % slopes = derivative_model(starting_gaps); % Result: [21, 41, 61, 81]
% % 
% % %----------------
% % %   Employ MPC
% % %----------------
% % num_inputs = 4;
% % num_outputs = 16;
% % 
% % A_mat = zeros(num_inputs, num_inputs); % No state-to-state cross coupling
% % B_mat = eye(num_inputs);               % Inputs pass directly into the delay state
% % 
% % % Populate the C matrix with your analytical slopes instead of D
% % C_mat = zeros(num_outputs, num_inputs);
% % for i = 1:4
% %     C_mat((i-1)*4 + 1 : i*4, i) = slopes(i);
% % end
% % 
% % D_mat = zeros(num_outputs, num_inputs); % FORCE DIRECT FEEDTHROUGH TO ZERO
% % 
% % % Construct the valid state-space model
% % plant_model = ss(A_mat, B_mat, C_mat, D_mat, 'Ts', Ts);
% % 
% % 
% % % --- Calculate Nominal Values (Operating Point) ---
% % u0 = starting_gaps(:); % Inputs at operating point (column vector)
% % 
% % % Compute absolute outputs at the operating point using the non-linear equation
% % S_vector = [
% %     nonlinear_model(starting_gaps(1)), nonlinear_model(starting_gaps(1)/2), ...
% %     nonlinear_model(starting_gaps(1)/3), nonlinear_model(starting_gaps(1)/4);
% %     nonlinear_model(starting_gaps(2)), nonlinear_model(starting_gaps(2)/2), ...
% %     nonlinear_model(starting_gaps(2)/3), nonlinear_model(starting_gaps(2)/4);
% %     nonlinear_model(starting_gaps(3)), nonlinear_model(starting_gaps(3)/2), ...
% %     nonlinear_model(starting_gaps(3)/3), nonlinear_model(starting_gaps(3)/4);
% %     nonlinear_model(starting_gaps(4)), nonlinear_model(starting_gaps(4)/2), ...
% %     nonlinear_model(starting_gaps(4)/3), nonlinear_model(starting_gaps(4)/4)
% % ];
% % 
% % y0 = S_vector(1:16); % 16 nominal output points matching the matrix size
% % x0 = []; % Abstract states for a static gain system is 0
% % 
% % 
% % minMat = zeros(1, 16);
% % for i = 1:16
% %     minMat(i) = -60;
% % end
% % 
% % P = 20; %number of steps/iterations
% % C = floor(0.1 * P);
% % 
% % MV = struct('Min',{1,1,1,1},'Max',{500, 500, 500, 500},'ScaleFactor',{50, 50, 50, 50});
% % OV = struct('Min',{-60,-60,-60,-60},'Max',zeros(1, 16),'ScaleFactor',abs(minMat));
% % 
% % W = struct('MV',[0 0 0 0],'MVRate',ones(1, 4) * 0.1,'OV',[200, 200, 200, 200]);
% % 
% % 
% % % --- Initialize MPC Object ---
% % mpcObj = mpc(plant_model, Ts, P, C, W, MV, OV);
% % 
% % mpcObj.ManipulatedVariablesRate =  % Soft rate constraint penalization
% % predictionTime = mpcObj.PredictionHorizon * mpcObj.Ts; %prediction time
% % 
% % % Set Constraints dynamically based on the exact variable lengths
% % for i = 1:length(mpcObj.ManipulatedVariables)
% %     mpcObj.ManipulatedVariables(i).Min = 1;
% %     mpcObj.ManipulatedVariables(i).Max = 4000; 
% % end
% % for j = 1:length(mpcObj.OutputVariables)
% %     mpcObj.OutputVariables(j).Min = 1;
% %     mpcObj.OutputVariables(j).Max = 4000;
% % end
% % 
% % % Set Nominal Operating Point parameters
% % % This informs the Linear MPC exactly where the linear tangent plane rests
% % mpcObj.Model.Nominal.X = x0;
% % mpcObj.Model.Nominal.U = u0;
% % mpcObj.Model.Nominal.Y = y0;
% % 
% % %----------------
% % %   Plot Figures 
% % %----------------
% % 
% % % figure('Name', '4-Port S-Parameter Performance');
% % % subplot(2,1,1);
% % % plot(freq_axis/1e9, final_S(1,:), 'b-', 'LineWidth', 2); hold on; % S11
% % % plot(freq_axis/1e9, target_S(1,:), 'r--', 'LineWidth', 1.5);
% % % title('Input Match (S_{11})');
% % % xlabel('Frequency (GHz)'); ylabel('Magnitude (dB)');
% % % grid on; legend('Tuned', 'Target');
% % % 
% % % subplot(2,1,2);
% % % plot(freq_axis/1e9, final_S(4,:), 'm-', 'LineWidth', 2); hold on; % S41 (Isolation)
% % % title('High Isolation Path (S_{41})');
% % % xlabel('Frequency (GHz)'); ylabel('Magnitude (dB)');
% % % grid on; 
% % 
% % 
% % time_steps = 1:size(gap_history, 1);
% % 
% % figure('Name', 'MPC Actuator Gap Trajectories');
% % plot(time_steps, gap_history(:,1), '-o', 'LineWidth', 1.5); hold on;
% % plot(time_steps, gap_history(:,2), '-s', 'LineWidth', 1.5);
% % plot(time_steps, gap_history(:,3), '-^', 'LineWidth', 1.5);
% % plot(time_steps, gap_history(:,4), '-d', 'LineWidth', 1.5);
% % 
% % % Plot the hard physical boundaries to verify constraints
% % yline(1, 'r--', 'Lower Constraint (1 mil/mm)', 'LineWidth', 1.5);
% % yline(4000, 'r--', 'Upper Constraint (4000 mil/mm)', 'LineWidth', 1.5);
% % 
% % title('Mechanical Tuning Convergence');
% % xlabel('MPC Control Step (Iteration)');
% % ylabel('Absolute Gap Values');
% % legend('Gap 1', 'Gap 2', 'Gap 3', 'Gap 4', 'Constraints');
% % grid on;
% % 
% % 
% % figure;
% % plot(results, 'CriterionValue');
% % 
% % % while true
% % %     % 1. Measure actual non-ideal S-parameters from the VNA/ADS
% % %     y_measured = read_live_vna_data(); 
% % %     current_gaps = read_actuator_positions();
% % % 
% % %     % 2. Re-linearize the ideal model at the current actual position
% % %     % f'(x) = 2x + 1
% % %     current_slopes = 2 .* current_gaps + 1;
% % % 
% % %     % Rebuild the linear matrix dynamically
% % %     K_adaptive = zeros(16, 4);
% % %     for i = 1:4
% % %         K_adaptive((i-1)*4 + 1 : i*4, i) = current_slopes(i);
% % %     end
% % % 
% % %     % 3. Update the MPC object's internal model on-the-fly
% % %     % This forces the linear MPC to twist its internal map to track the non-ideal state
% % %     mpcObj.Model.Plant = ss([], [], [], K_adaptive, 'Ts', Ts);
% % % 
% % %     % Update nominal baseline anchors with the live non-ideal data
% % %     mpcObj.Model.Nominal.U = current_gaps;
% % %     mpcObj.Model.Nominal.Y = y_measured; 
% % % 
% % %     % 4. Compute the corrected move
% % %     [updated_gaps, info] = mpcmove(mpcObj, x_mpc, y_measured, target_y);
% % % 
% % %     send_commands_to_motors(updated_gaps);
% % %     pause(Ts);
% % % end