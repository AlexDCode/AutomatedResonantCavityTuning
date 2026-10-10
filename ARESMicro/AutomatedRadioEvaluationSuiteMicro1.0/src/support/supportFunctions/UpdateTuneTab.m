function UpdateTuneTab(app)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION:
% Updates the slider and boxes in the tune tab from new gap values obtained in other tabs.
%
% INPUT:
%   app            - MATLAB application object
%
% OUTPUT:
%   void
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Only attempt to update UI if gaps were successfully retrieved
    if ~isempty(app.getGaps)
        
        % Update all UI elements with new values
        for idx = 1:numel(app.getGaps)
            newValue = app.getGaps(idx);
            newValue = round(newValue);
            % Update the Sliders array
            app.slider(idx).Value = newValue;
            
            % Update the tracking Edit Boxes array 
            app.editGaps(idx).Value = newValue;
        end
    end
end