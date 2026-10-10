function [bestGaps, costHistory, gapHistory, minCGap, maxCGap] = evaGradAlgo(app)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% This function uses gradient descent, with a device 'live', or by using a
% surrogate model to approximate the device characteristics. The goal of
% this method is to minimize the cost by finding global minimum.
%
% INPUT:
%   app            - MATLAB application object
%
% OUTPUT:
%   bestGaps       - The best gap values found
%   costHistory    - An array of costs values after each program iteration
%   gapHistory     - An array of gap values after each program iteration
%   minCGap        - The minimum gap of the actuator corresponding to the
%                    highest capacitance
%   maxCGap        - The maximum gap before any increases cause negligible
%                    changes in capacitance.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %% GET INITIAL VALUES
    etaMin = 1e-4;
    eta = repmat(app.startingEta, 1, 4);
    
    gradNew = zeros(4, 1);

    minCGap = 1;
    iteration = 0;

    costHistory = NaN(app.iteratePrecisionation);
    gapHistory = NaN(app.iteratePrecisionation, 4);
    etaHistory = NaN(3, 4);
    
    [bestGaps, maxCGap, ~, cost, worstCost, beta_, coVar, span] = findBestStartPosDCC(app);
    disp("Best Gaps: " + mat2str(bestGaps))

    %This is the theoretical cost
    objectiveFunction = @(x) ( ...
        beta_(1) + ...                                                       % Intercept / Base state
        sum(beta_(2:5)' .* x) + ...                                       % Linear sensitivities (x1, x2, x3, x4)
        sum(beta_(6:9)' .* (x.^2)) + ...                                  % Self-loading curvatures (x1^2, x2^2, x3^2, x4^2)
        beta_(10)*x(1)*x(2) + beta_(11)*x(1)*x(3) + beta_(12)*x(1)*x(4) + ...  % Cross-couplings from Cavity 1
        beta_(13)*x(2)*x(3) + beta_(14)*x(2)*x(4) + ...                       % Cross-couplings from Cavity 2
        beta_(15)*x(3)*x(4) ...                                              % Cross-coupling between 3 and 4
        - app.targetCost ...
    ).^2;
    
    if app.useSurrogateModel
        % x represents capacitance because the formulas are more linear
        [~, x] = getDiskCapacitances(bestGaps);
        grad = getAnalyticalGradient(app, x, beta_);

        %Normalize Objective function
        %normalizer =  mean(objectiveFunction(x)) / cost;
        surrogateScaleFactor = cost / mean(objectiveFunction(x));

    else
        x = bestGaps;
        grad = getDeviceGrad(app, x, beta_, eta, cost, minCGap, span);
    end

    
    %% ENTER MAIN LOOP
    while cost > app.targetCost && iteration < app.iteratePrecision
        iteration = iteration + 1;
        xNew = x - (eta .* grad);

        if app.useSurrogateModel
            % Calculate new raw positions

            % If using surrogate, we must clip capacitances to prevent physically impossible bounds
            [~, minC] = getDiskCapacitances(repmat(maxCGap, 1, 4));
            [~, maxC] = getDiskCapacitances(repmat(minCGap, 1, 4));
         
            xNew = min(max(xNew, minC), maxC);
        else
            xNew = round(xNew); 
            xNew = min(max(xNew, minCGap), maxCGap);
        end

        disp("Iteration: " + iteration)
        disp("COST: " + cost)
        %disp("Eta: " + mat2str(eta, 4))
        disp("Grad: " + grad)
        disp("x: "+ x)
        disp("xNew: " + xNew)

        % --Update the Gradient--
        if app.useSurrogateModel
            newCost = mean(objectiveFunction(xNew)) * surrogateScaleFactor;
            if newCost <= cost
                disp("GoodCost: " + newCost)
                cost = newCost;
                gradNew = getAnalyticalGradient(app, xNew, beta_);
                x = xNew;
            else
                disp("BadCost: " + newCost)
                gradNew = 0.5 .* getAnalyticalGradient(app, xNew, beta_);
                
            end

        else
            [newCost, ~] = calculate_device_cost(app, xNew);

            %[beta_, coVar] = updateBetaRecursive(xNew, newCost, beta_, coVar);

            % Update running best cost
            if newCost <= cost
                cost = newCost;
                gradNew = getDeviceGrad(app, x, beta_, eta, cost, minCGap, span);
                x = xNew;
            else
                %go the other way
                gradNew = -getDeviceGrad(app, x, beta_, eta, cost, minCGap, span); 
                gradNew = gradNew ./ 1.5;
            end
        end

        % Log current state for optimization plotting
        costHistory(iteration) = cost;

        if app.useSurrogateModel
            gaps = getGapsFromCapacitance(x);
            gapHistory(iteration, :) = gaps;
        else
            gapHistory(iteration, :) = x;
        end

        %--------------------------------------------

        if isscalar(gradNew)
            gradNew = repmat(gradNew, 1, 4); 
        else
            gradNew = gradNew(:).';
        end
        
        if app.useVariableEta
            deltaPos = xNew - x;
            deltaGrad = gradNew - grad;
            denom = norm(deltaGrad).^2;
            disp("Delta Pos:" + mat2str(deltaPos))
            disp("Delta Grad:" + mat2str(deltaGrad))
            etaNew = abs(deltaPos .* deltaGrad) ./ (denom + 1e-15);
    
            % If an actuator got clipped to limits, its deltaPos is artificially zero.
            % Keep previous learning rate active instead of freezing it.
            if app.useSurrogateModel
                clippedMask = (xNew <= minC) | (xNew >= maxC);
            else
                clippedMask = (xNew <= minCGap) | (xNew >= maxCGap);
            end
    
            etaNew(clippedMask) = eta(clippedMask);
    
            % Apply element-wise limits to each eta
            eta = min(max(etaNew, etaMin), app.startingEta);
    
            % Slide old rows up, and append the new 1x4 eta vector at the bottom
            etaHistory = [etaHistory(2:3, :); eta];
    
            % Checks if all 4 individual eta channels have remained completely unchanged 
            if all(etaHistory(1, :) == etaHistory(2, :)) && all(etaHistory(2, :) == etaHistory(3, :))
                break;
            end
        end
        grad = gradNew;
    end

    %% Function Results
    if app.useSurrogateModel
        disp("Final X: " + x)
        bestGaps = getGapsFromCapacitance(x);
        disp("FINAL GAPS: " + bestGaps)

        if bestGaps(1) > maxCGap
            fprintf("GAP HAS MAXED OUT")
            bestGaps = maxCGap .* ones(1, length(bestGaps));
        
        elseif bestGaps(1) < minCGap
            fprintf("GAP HAS MINNED OUT")
            bestGaps = minCGap .* ones(1, length(bestGaps));
        end
    else
        bestGaps = x;
    end

    % Send final optimal physical positions to Pico
    commandAllGaps(bestGaps);
end
