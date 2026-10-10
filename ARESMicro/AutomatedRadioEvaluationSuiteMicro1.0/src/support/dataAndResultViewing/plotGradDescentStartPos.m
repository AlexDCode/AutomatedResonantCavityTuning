function plotGradDescentStartPos()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% This function shows the starting positions used in gradient descent from
% employing a variation of the central composite design method (exclusion
% of star points).
%
% INPUT:
%   None
%
% OUTPUT:
%   void
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Generate the 4-factor central composite design
    dCC = unique(ccdesign(4, 'Type', 'faced'), 'rows', 'stable');

     % Plot the pairwise design matrix space
    figure();
    [~, AX, BigAx] = plotmatrix(dCC);
    labels = {'Actuator A', 'Actuator B', 'Actuator C', 'Actuator D'};
    for i = 1:4
        ylabel(AX(i,1), labels{i}, 'FontWeight', 'bold'); 
        xlabel(AX(4,i), labels{i}, 'FontWeight', 'bold'); 
    end
    title(BigAx, 'Pairwise Experimental Space for 4-Actuator Design', 'FontSize', 12);    
end