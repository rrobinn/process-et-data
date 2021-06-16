% Function breaks up time series data from a trial into its 5 segments.
% Segment times are defined by function getSegmentTimeStamps.
% Very similar to generate_timeseries.m,except that output is a bit
% different

% Output includes:
% 1. Time series
% 2. Media name (repeated for each row)
% 3. Segment number (repeated)
% 4. Proportion of missing data for entire segment (Repeated)
% 5. Cumulative fixation length - this ignores blinks (in frames)
% 6. Longest stream of continuous data (in frames)
% 7. blink boolean
function [segmentedData_calVer, calVerCol] = generate_timeseries_calver(PrefBin, ParticData, dataCol)
%% Input for debugging
% id = 'JE000084_04_07';
% inputFileDir = '/Users/sifre002/Google Drive/7_MatFiles/01_Complexity/IndividualData/';
% infile = [inputFileDir id '/' id '_ParsedData.mat'];
%% generate struct of column headers for output 
calVerCol = struct();
calVerCol.timestamp = 1;
calVerCol.x = 2;
calVerCol.y = 3;
calVerCol.blink = 4; 
calVerCol.amp = 5;
calVerCol.arctan = 6;
calVerCol.id = 7;
calVerCol.longestFixDur = 8;
calVerCol.longestFixBool = 9;
calVerCol.propMissing = 10;
calVerCol.propInterpolated = 11;
calVerCol.trial =12;
calVerCol.date = 13;
%%
trialList = {'Center_converted.avi' ,'BottomLeft_converted.avi', 'BottomRight_converted.avi', ...
    'TopLeft_converted.avi', 'TopRight_converted.avi'};
maxInt = 200; % max missing window that will be interpolated
%%


segmentedData_calVer = cell(8*5, 1); % empty cells will be deleted at end
count = 1;
for t = 1:size(PrefBin.MovieListAsPresented,1)
    
    if ~isempty( intersect(PrefBin.MovieListAsPresented{t}, trialList) ) % Check if this is a Calver trial
        data = ParticData.Data{t,1};
        data_interp = ParticData.Data{t,2};
        
        % If trial cut short, continue
        if size(data,1) < 10
            continue
        end
        
        trialName = PrefBin.MovieListAsPresented{t};
        % Subtract off first time stamp so that the first time stamp = 0
        time = cell2mat(data(:, dataCol.timestamp));
        time = time - time(1);
        % Select columns
        d = ...
            [cell2mat(data(:, dataCol.timestamp)), ... % 1
             cell2mat(data(:, dataCol.gazeX)), ...
             cell2mat(data(:, dataCol.gazeY)), ... %2,3
             cell2mat(data(:, dataCol.blink)) ]; %4
        d = double(d(:,:));
        % fill in missing data from blinks - blinks won't be counted in
        % missing data, or when finding the longest continuous data
        blinkLogic = logical(d(:,4));
        d(blinkLogic, 2) = data_interp(blinkLogic, 1); % fill in x-data
        d(blinkLogic, 3) = data_interp(blinkLogic, 2); % fill in x-data
        
        missingLogic = d(:,2) == - 9999;
        [L, num] = bwlabel(missingLogic);
        segtime = d(:,1) - d(1,1);
        
        nFramesInterpolated = 0;
        for i = 1:num % interpolate for missing segments < 200 ms
            tempLogic = L == i; % Find indices of the missing data
            if tempLogic(1) == 1 | tempLogic(end) == 1;
                % Do nothing. Can't interpolate the missing data at the very
                % beginning, or at the very end
            else
                % Find missing indices
                first = find(tempLogic, 1, 'first');
                last = find(tempLogic, 1, 'last');
                
                if segtime(last, 1) - segtime(first,1) >= maxInt
                    % Do nothing, it's too long to interpolate
                else  % pull data, with padding before and after
                    d(tempLogic, 2) = data_interp(tempLogic, 1);
                    d(tempLogic, 3) = data_interp(tempLogic, 2);
                    nFramesInterpolated = nFramesInterpolated + sum(tempLogic);
                end
            end % end statement that checks for missing data at beginning of clip
        end
        
        % calculate amplitude & arc tan
        x = d(:,2);
        y = d(:,3);

        x(x==-9999) = nan;
        y(y==-9999) = nan;

        % calculate the distance between two datapoints
        temp_x = diff(x) .^2;
        temp_y = diff(y) .^2;
        dist = sqrt( temp_x + temp_y );
        % Calculate the time between two datapoints
        t_amp = d(:,1);
        t_amp = diff(t_amp);
        %
        amp = dist./t_amp;
        amp = [amp; 0]; % append 0 to the last idx

        % arctan = atan(amp);
        arctan = atan(temp_y./temp_x);
        arctan = [arctan; 0];
        
        d = [d amp arctan];
        
        % identify longest stream of continuous data
        longestDur = d(:, 2) ~= -9999;
        [L, num] = bwlabel(longestDur);
        fixDur = zeros(length(d),1);
        for i = 1:num
            fixInd = find(L == i);
            fixDur(fixInd,1) = segtime(fixInd(end)) - segtime(fixInd(1)); % fixation dur
        end
        longestFix = max(fixDur);
        longestFix_log = fixDur==longestFix;
        % identify prop missing AFTER interpolation
        propMissing = sum(d(:,2) == -9999) / length(d(:,2));
        
        % identify prop interpolated
        propInterpolated = nFramesInterpolated / length(d(:,2));
               
        % put data together
        temp = cell(length(d), 6);
        temp(:,1) = {[PrefBin.ParticipantName '_' PrefBin.SessionNumber]};
        temp(:,2) = {longestFix};
        temp(:,3) = num2cell(longestFix_log);
        temp(:,4) = {propMissing};
        temp(:,5) = {propInterpolated};
        temp(:,6) = {trialName};
        temp(:,7) = {PrefBin.TimeOfDataCollection};

        segmentedData_calVer{count,1} =  horzcat(num2cell(d), temp);
        count = count + 1;
        
    end
    
end % trial loop




