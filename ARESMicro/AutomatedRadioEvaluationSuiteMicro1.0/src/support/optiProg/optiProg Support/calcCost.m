function cost = calcCost(condition, target, weight, data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% Sends the command to the Pico to update an individual actuator.
%
% INPUT:
%   condition      - user entered condition (<,>,=,None)
%   target         - user entered target value
%   weight         - user entered weight
%   data           - VNA measured data
%
% OUTPUT:
%   cost           - resultant cost of a metric compared to its target
%                    value.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if strcmp(condition, "=")
        cost = weight * abs(data - target) / abs(target);
    elseif strcmp(condition, "<")
        cost = weight * max(0, data - target) / abs(target);
    elseif strcmp(condition, ">")
        cost = weight * max(0, target - data) / abs(target);
    elseif strcmp(condition, "None")
        cost = 0;
    else
        error("Unknown condition");
    end
end