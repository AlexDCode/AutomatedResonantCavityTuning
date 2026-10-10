%% Setup
n = 25; % Number of iterations
numActuators = 4; %Number of actuators

% Generate the 4-factor central composite design

dCC = unique(ccdesign(4, 'Type', 'faced'), 'rows', 'stable');

maxCGap = round(findMaxGap());
minCGap = 10;

midCGap = sqrt(minCGap * maxCGap); % Because gap values are logarithmic, not linear.
actuatorPos = round(midCGap) * ones(size(dCC));
worstCost = 0;

% Define the physical actuator travel range
span = maxCGap - minCGap;

actuatorPos(dCC == 1) = maxCGap;
actuatorPos(dCC == -1) = minCGap;

% Plot the pairwise design matrix space
figure();
[~, AX, BigAx] = plotmatrix(dCC);
labels = {'Actuator A', 'Actuator B', 'Actuator C', 'Actuator D'};
for i = 1:4
    ylabel(AX(i,1), labels{i}, 'FontWeight', 'bold'); 
    xlabel(AX(4,i), labels{i}, 'FontWeight', 'bold'); 
end
title(BigAx, 'Pairwise Experimental Space for 4-Actuator Design', 'FontSize', 12); 
numPoints = length(actuatorPos);

Dataset = zeros(numPoints + n); %contains history of inputs and outputs
theta = zeros(numActuators); % Input values for actuators
thetaMin = minCGap;
thetaMax = maxCGap;

aEI = ; % Cost acquisition function
aCEI = ; % Control acquisition function

%% Get initial Samples through CCD?

for i = 1:numPoints
    %update data set

end


%% Training
%train G(f) for f(theta)
%train G(p) with data set


%% Update:
for i = 1:n
%compute theta n+1 via acquisition function

%Evaluate F, Z ← (f(theta), g(theta))

%Update data set

%Update Surrogate model
end

bestGaps = theta;


