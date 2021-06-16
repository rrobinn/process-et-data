% Function breaks up data from a trial into its 5 time series. 
% Segment times are defined by function getSegmenttimestamps.
% Written by Robin Sifre (robinsifre@gmail.com)

function [segmentedData,segSummaryCol] = generate_timeseries(ParticData, PrefBin, dataCol)
%% Input for debugging
%id = 'JE000084_04_07';
%inputFileDir = '/Users/sifre002/Google Drive/7_MatFiles/01_Complexity/IndividualData/';
%infile = [inputFileDir id '/' id '_ParsedData.mat'];
%% generate struct of column headers for output 
segSummaryCol = struct();
segSummaryCol.timestamp = 1;
segSummaryCol.x = 2;
segSummaryCol.y = 3;
segSummaryCol.blinkBool = 4;
segSummaryCol.amp = 5;
segSummaryCol.arctan = 6;
segSummaryCol.id = 7;
segSummaryCol.longestFixDur = 8;
segSummaryCol.longestFixBool = 9;
segSummaryCol.propMissing = 10;
segSummaryCol.propInterpolated = 11;
segSummaryCol.trial = 12;
segSummaryCol.seg = 13;
segSummaryCol.aoi = 14;
segSummaryCol.vl = 15;
segSummaryCol.vr = 16;
segSummaryCol.date = 17;

%% 
trialList = {'01_converted.avi', '01S_converted.avi', ...
    '03_converted.avi', '03S_converted.avi', ...
    '04_converted.avi', '04S_converted.avi', ...
    '05_converted.avi', '05S_converted.avi'};
maxInt = 200; % max missing window that will be interpolated
%%
% pre-allocate output - empty cells will be deleted at end
segmentedData = cell(8*5, 1); 
count = 1;
for t = 1:size(PrefBin.MovieListAsPresented,1)
    if ~isempty( intersect(PrefBin.MovieListAsPresented{t}, trialList) ) % Check if this is a dancing ladies trial
        % pull original data, interpolated data, and aoi-hits data for this
        % trial
        data = ParticData.Data{t,1};
        data_interp = ParticData.Data{t,2};
        data_aoi = ParticData.Data{t,3}; 
        trialName = PrefBin.MovieListAsPresented{t};
        % Subtract off first time stamp so that the first time stamp = 0
        time = cell2mat(data(:, dataCol.timestamp)); 
        time = time - time(1);
        
        % Find the time stamps closest to the ones in output from getSegmenttimestamps.m
        [segtimestamps] = getSegmentTimeStamps(trialName);
        
        % if they didn't see the whole movie, then skip
        if max(time) < 20000
            continue
        end
        % find timestamp closest to when time series is meant to start
        segInd = zeros(length(segtimestamps) + 1,1);
        for s = 1:length(segtimestamps)
            [minDist, indexOfMin] = min ( abs( time - segtimestamps(s) ) ); 
            segInd(s) = indexOfMin;
        end
        segInd(end) = size(data,1); % last frame

        %% Segment the trial & pull relevant data
        for s = 1:length(segInd)-1
            %% Pull data for segment
            % Select rows from original data, interpolated data, and
            % aoi-hit data
            tempData = data(segInd(s):segInd(s+1)-1, :);
            
            % If there are fewer than 100 rows of data in this segment
            % chunk, skip (trial was cut short)
            if size(tempData,1) < 100
                continue
            end
            
            
            tempData_interp = data_interp(segInd(s):segInd(s+1)-1, :);
            tempData_aoi = data_aoi(segInd(s):segInd(s+1)-1, :);
            % pull time, and (x,y) coordinates from original data 
            t = cell2mat( tempData(:, dataCol.timestamp) );
            x = cell2mat( tempData(:, dataCol.gazeX) );
            y = cell2mat( tempData(:, dataCol.gazeY) );
            blink = cell2mat( tempData(:, dataCol.blink) ); % blink boolean
            vr = cell2mat( tempData(:, dataCol.validityR)); % validity code for l/r
            vl = cell2mat( tempData(:, dataCol.validityL));

            % fill in data that are missing b/c of blinks with interpolated data - blinks won't be counted in
            % missing data, or when finding the longest continuous data
            blinkLogic = logical(blink);
            x(blinkLogic) = tempData_interp(blinkLogic, 1); % fill in x-data
            y(blinkLogic) = tempData_interp(blinkLogic, 2); % fill in x-data
            
            %% Add in interpolated data where missing
            % fill in data that are missing (not b/c of blinks) with
            % interpolated data. Checks that missing segment is <= maxInt
            missingLogic = x == - 9999; 
            [L, num] = bwlabel(missingLogic);
            segtime = t(:,1) - t(1,1);
            nFramesInterpolated = 0; % keep track of how many frames we have interpolated
            for i = 1:num % interpolate for missing segments < 200 ms
                tempLogic = L == i; % Find indices of the missing data
                if tempLogic(1) == 1 | tempLogic(end) == 1
                    % Do nothing. Can't interpolate the missing data at the very
                    % beginning, or at the very end
                else
                    % Find missing indices
                    first = find(tempLogic, 1, 'first');
                    last = find(tempLogic, 1, 'last');
                    if segtime(last, 1) - segtime(first,1) >= maxInt
                        % Do nothing, it's too long to interpolate
                    else  % pull data, with padding before and after
                        x(tempLogic, 1) = tempData_interp(tempLogic, 1);
                        y(tempLogic, 1) = tempData_interp(tempLogic, 2);
                        nFramesInterpolated = nFramesInterpolated + sum(tempLogic); 
                    end
                end % end statement that checks for missing data at beginning of clip
            end
            
            % identify longest stream of continuous data (this is what will
            % be used in analyses)
            longestDur = x ~= -9999;
            [L, num] = bwlabel(longestDur);
            fixDur = zeros(length(x),1);
            for i = 1:num
                fixInd = find(L == i);
                fixDur(fixInd,1) = segtime(fixInd(end)) - segtime(fixInd(1)); % fixation dur
            end
            longestFix = max(fixDur);
            longestFix_log = fixDur==longestFix;
            % identify prop missing AFTER interpolation
            propMissing = sum(x == -9999) / length(x);
            % identify prop interpolated 
            propInterpolated = nFramesInterpolated / length(x); 
            %% calculate amplitude & arc tan
            x1 = x;
            y1 = y;
            x1(x1==-9999) = nan;
            y1(y1==-9999) = nan;

            % calculate the distance between two datapoints
            temp_x = diff(x1) .^2;
            temp_y = diff(y1) .^2;
            dist = sqrt( temp_x + temp_y );
            % Calculate the time between two datapoints
            t1 = segtime;
            t1 = diff(t1);
            %
            amp = dist./t1;
            amp = [amp; 0]; % append 0 to the last idx

            % arctan = atan(amp);
            arctan = atan(temp_y./temp_x);
            arctan = [arctan; 0];
                
            %% save time series data 
            temp = cell(length(x), numel(fieldnames(segSummaryCol)));
            temp(:,segSummaryCol.timestamp) = num2cell(t);
            temp(:,segSummaryCol.x) = num2cell(x); 
            temp(:,segSummaryCol.y) = num2cell(y); 
            temp(:,segSummaryCol.blinkBool) = num2cell(blink); 
            temp(:,segSummaryCol.amp) = num2cell(amp); 
            temp(:,segSummaryCol.arctan) = num2cell(arctan);
            temp(:,segSummaryCol.id) = {[PrefBin.ParticipantName '_' PrefBin.SessionNumber]};
            temp(:,segSummaryCol.longestFixDur) = {longestFix};
            temp(:,segSummaryCol.longestFixBool) = num2cell(longestFix_log);
            temp(:,segSummaryCol.propMissing) = {propMissing};
            temp(:,segSummaryCol.propInterpolated) = {propInterpolated}; 
            temp(:,segSummaryCol.trial) = {trialName};
            temp(:,segSummaryCol.seg) = {s};
            temp(:,segSummaryCol.aoi) = num2cell(tempData_aoi);
            temp(:,segSummaryCol.vl) = num2cell(vl);
            temp(:,segSummaryCol.vr) = num2cell(vr);
            temp(:,segSummaryCol.date) = {PrefBin.TimeOfDataCollection};
            
            segmentedData{count,1} =  temp; 
            count = count + 1;
        end % segment loop 
    end 
end % trial loop




