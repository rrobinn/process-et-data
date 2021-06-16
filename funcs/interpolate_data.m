function [propInterpolated, ParticData, PrefBin] = interpolate_data(ParticData, PrefBin, plotFlag, dataCol, varargin)
% Script adds interpolated data to to ParticData.Data (a struct).
close all
maxInt = 100000000; % Maximum interval of missing data to be interpolated. Set to large number if you want everything interpolated.
avgWindow = 1; % must be at least 1. Tobii's algorithm checks first valid data before/after gap.

strictValidityFlag = 0;
switch length(varargin)
    case 0 % no options
    case 1 % one additional variable
        if strcmpi(varargin{1}, 'strict')
            strictValidityFlag=1;
        else
            error(['Unknown input variable: ' varargin{1}]);
        end
    case 2 % options as <name-value> pairs
        if strcmpi(varargin{1}, 'strict')
            strictValidityFlag = varargin{2};
        end
    otherwise(error('Unknown input variable'));
end
if strictValidityFlag~=0 & strictValidityFlag~=1 
    error('strict flag must be set to 0 or 1')
end
disp(['\n Interpolating data. strictValidityFlag set to ' num2str(strictValidityFlag) '\n']);

PrefBin.StrictValidityFlag = strictValidityFlag;
%% Select data
propInterpolated = zeros(length(ParticData.Data),1);
if isempty(ParticData.Data) % quit if there is no data.
    return
end

for c = 1:size(ParticData.Data,1) % for each trial
    temp = ParticData.Data{c,1};
    %% Find missing data
    % Depending on how strict you want to be, user can either a) just flag
    % missing frames (vl/vr==-9999), or b) add additional logic that chekcs
    % their validity code. tobii recommends removing code 2 or higher.
    vl = cell2mat(temp(:, dataCol.validityL)); % pull validity code for left and right eye
    vr = cell2mat(temp(:, dataCol.validityR));
    gazeX = cell2mat( temp(:, dataCol.gazeX) ); % pull x and y coordinates
    gazeY = cell2mat( temp(:, dataCol.gazeY) );
    time = cell2mat( temp(:, dataCol.timestamp) );
    
    % Can choose how strict to be here. Use first two lines to be stricter.
    if strictValidityFlag
        logic1 = vl <= 1 & vl~= -9999;  % may be too stringent. tobii recomends removing code of 2 and higher
        logic2 = vr <= 1 & vl~= -9999;
    else
        logic1 = vl~= -9999; % only remove missing data.
        logic2 = vr ~= -9999;
    end
    
    finalLogic = logic1 & logic2; % both eyes are NOT missing
    gazeX(~finalLogic) = -9999; % if data are invalid (low quality), or are missing.
    gazeY(~finalLogic) = -9999;
    
    %% Find missing data to interpolate
    missingLogic = gazeX == - 9999;
    propInterpolated(c,1) = sum(missingLogic)/numel(missingLogic); % keep track of % interpolated for output
    [L, num] = bwlabel(missingLogic);
    
    % copy data to interpolate
    gazeX_int = gazeX;
    gazeY_int = gazeY;
    
    for i = 1:num
        tempLogic = L == i; % Find missing data
        if tempLogic(1) == 1 | tempLogic(end) == 1 % Checks if first or last frame - can't interpolate these.
            % do nothing
        else
            % Find missing indices
            first = find(tempLogic, 1, 'first');
            last = find(tempLogic, 1, 'last');
            
            if temp{last, dataCol.timestamp} - temp{first, dataCol.timestamp} >= maxInt % check if missing segment is longer than maxInt
                % Do nothing, it's too long to interpolate
            else  % pull data, with padding before and after
                xpad = gazeX(max(first - avgWindow, 1) : min(last + avgWindow, length(gazeX)) );
                ypad = gazeY(max(first - avgWindow, 1) : min(last + avgWindow, length(gazeY)) );
                tpad = time(max(first - avgWindow, 1) : min(last + avgWindow, length(time)) );
                
                %t = time(first:last);
                xpad(xpad==-9999) = nan;
                ypad(ypad==-9999) = nan;
                
                % Get fix-position data before and after the gap
                after_X = mean( xpad(length(xpad) - avgWindow + 1: length(xpad)) );
                after_Y = mean( ypad(length(ypad) - avgWindow + 1: length(ypad)) );
                
                before_X = mean( xpad(1:avgWindow) );
                before_Y = mean( ypad(1:avgWindow) );
                
                % interpolation
                %gapDur = tpad(end) - tpad(1);
                x = [1 length(tpad)];
                % Interpolate X
                v = [before_X after_X];
                xq = [1:length(tpad)];
                int_X = interp1(x,v,xq);
                
                % Interpolate Y
                v = [before_Y after_Y];
                int_Y = interp1(x,v,xq);
                
                % save interpolated data
                gazeX_int(tempLogic) = int_X(2:length(int_X)-1);
                gazeY_int(tempLogic) = int_Y(2:length(int_Y)-1);
                
            end
        end % end statement that checks for missing data at beginning of clip
    end
    ParticData.Data{c,2} = [gazeX_int gazeY_int]; % add interpolated data to ParticData
    
    %% Visualizations of time series interpolation
    if plotFlag
        clip = PrefBin.MovieListAsPresented{c,1};
        
        gazeX(gazeX==-9999) = nan;
        gazeY(gazeY==-9999) = nan;
        gazeX_int(gazeX_int==-9999) = nan;
        gazeY_int(gazeY_int==-9999) = nan;
        
        
        figure('Position', [100 100 1000 1000]);
        subplot(2,1,1);
        % Plot X data
        plot([1:length(gazeX_int)], gazeX_int, '-r', 'linewidth', 3);
        hold on;
        plot([1:length(gazeX)], gazeX, '-b', 'linewidth', 4);
        xlabel('Data frame', 'fontsize', 16);
        ylabel('X-coordinate', 'fontsize', 16);
        
        % Plot Y Data
        subplot(2,1,2);
        plot([1:length(gazeY_int)], gazeY_int, '-r', 'linewidth', 3);
        hold on;
        plot([1:length(gazeY)], gazeY, '-b', 'linewidth', 4);
        xlabel('Data frame', 'fontsize', 16);
        ylabel('Y-coordinate', 'fontsize', 16);
        
        suptitle([partic '-' clip]);
    end
end







