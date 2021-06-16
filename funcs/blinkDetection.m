% blinkDetection.m
% Algorithm by Hershman, Henik, & Cohen (2018), Behavior Research Methods
% This script is nearly identical to the code provided in their manuscript, but includes small adaptations.
% Specifically, allows user to flexibly input parameters, so that they can
% test how modifying parameters impacts blink detection in pediatric
% populations.
% Script adaptations written by Robin Sifre (sifre002@umn.edu). 

function [blinks_data_positions, params] = blinkDetection(pupil_data, sampling_rate_in_hz, varargin) 
% default parameters
working_blinks_data_positions = [];
sampling_interval     = 1000/sampling_rate_in_hz; % compute the sampling time interval in milliseconds.
gap_interval          = 100;                      % set the interval between two sets that appear consecutively for concatenation. (default = 100)
blink_length_min      = 100/sampling_interval;     % set the minimum blink length threshold (in frames) (defualt numerator = 100)
blink_length_max      = 400/sampling_interval;    % set the maximum blink length threshold (in frames) (default numerator = 400)
smooth_param          = 10; % default is 10
if(length(varargin)>1)
    for (i = 1:2:length(varargin))
        switch varargin{i}
            case 'gap_interval'
                gap_interval = varargin{i+1};
            case 'blink_length_min'
                blink_length_min = varargin{i+1};
            case 'blink_length_max'
                blink_length_max = varargin{i+1};
            case 'smooth_param'
                smooth_param = varargin{i+1};
        end
    end
    assert(blink_length_max > blink_length_min,'error: blinkDetection.m: maximum blink length must be > minimum blink length');
end

    %% Parameters
    params = struct();
    params.sampling_interval_frames = sampling_interval;
    params.gap_interval_frames = gap_interval;
    params.blink_length_min_frames = blink_length_min;
    params.blink_length_max_frames = blink_length_max;
    params.smooth_param = smooth_param;
    %% Setting the blinks' candidates array
    % explanations for line 17:
    % pupil_data==0 returns a matrix of zeros and ones, where one means missing values for the pupil (missing values represented by zeros).
    % it looks like: 0000001111110000
    % diff(n) = pupil_data(n+1)-pupil_data(n)
    % find(diff(pupil_data==0)==1) returns the first sample before the missing values 
    % find(diff(pupil_data==0)==-1) returns the last missing values
    % it looks like: 00000100000-1000 
    % blink onset is represented by a negative value and blink offset is represented by a positive value
    blinkstart = -1.*find(diff(pupil_data==0)==1);
    blinkstop = find(diff(pupil_data==0)==-1)+1; 
    %blinks      = vertcat(-1.*find(diff(pupil_data==0)==1), find(diff(pupil_data==0)==-1)+1);    
    
    % Case 1: there are no blinks
    if(isempty(blinkstart)||isempty(blinkstop))    
        blinks_data_positions = []; % RDS added this for when there are no blinks
        return;
    end;
    
    % Sort the blinks by absolute value. in this way we are getting an array of blinks when the offset appears after the onset 
    [~, idx] = sort(abs(blinkstart));
    blinkstart   = blinkstart(idx);
    [~, idx] = sort(abs(blinkstop));
    blinkstop   = blinkstop(idx);
    
    %[~, idx] = sort(abs(blinks));
    %blinks   = blinks(idx);

    %% Edge cases
    % Case 2: the data starts with a blink. In this case, blink onset will be defined as the first missing value.
    if(size(blinkstart, 1)>0 && blinkstart(1)+blinkstop(1)<=0) && pupil_data(1)==0 
        blinkstart = vertcat(-1, blinkstart);
    end;
    
    % Case 3: the data ends with a blink. In this case, blink offset will be defined as the last missing sample
    if(size(blinkstart, 1)>0 && (blinkstart(end)+blinkstart(end))<=0) && pupil_data(end)==0 
        blinkstop = vertcat(blinkstop, size(pupil_data, 1));
    end;

    %% Combine blinkstart and blinkstop 
    blinks = zeros((length(blinkstart)+length(blinkstop)),1);%initialize blinks
    for i = 1:length(blinkstart)
        blinks(2*i-1,1) = blinkstart(i);
        blinks(2*i,1) = blinkstop(i);
    end
          
    %% Smoothing the data in order to increase the difference between the measurement noise and the eyelid signal.
    ms_4_smoothing  = smooth_param;                                    % using a gap of 10 ms for the smoothing
    samples2smooth = ceil(ms_4_smoothing/sampling_interval); % amount of samples to smooth 
    smooth_data    = smooth(pupil_data, samples2smooth);    

    smooth_data(smooth_data==0) = nan;                      % replace zeros with NaN values
    diff_smooth_data            = diff(smooth_data);
    
    %% Finding the blinks' onset and offset
    blink                 = 1;                         % initialize blink index for iteration
    working_blinks_data_positions = zeros(size(blinks, 1), 1); % initialize the array of blinks
    prev_offset           = -1;                        % initialize the previous blink offset (in order to detect consecutive sets)    
    while blink < size(blinks, 1)
        % set the onset candidate
        onset_candidate = blinks(blink); % based on missing data 
        blink           = blink + 1;  % increase the value for the offset
        
        % set the offset candidate
        offset_candidate = blinks(blink);
        blink            = blink + 1;  % increase the value for the next blink
        
        % find blink onset
        data_before = diff_smooth_data(2:abs(onset_candidate)); % returns all the data before the candidate
        blink_onset = find(data_before>0, 1, 'last');           % returns the last 2 samples before the decline
        
        % Case 2 (the data starts with a blink. In this case, blink onset will be defined as the first missing value.)
        if isempty(blink_onset)
            blink_onset = abs(onset_candidate);
        end;
        
        % correct the onset if we are not in case 2
        if blink_onset>0 || pupil_data(blink_onset+2)>0
            blink_onset      = blink_onset+2;
        end;
        
        % find blink offset
        data_after  = diff_smooth_data(abs(offset_candidate):end); % returns all data after the candidate
        blink_offset = offset_candidate+find(data_after<0, 1);     % returns the last sample before the pupil increase

        % Case 3 (the data ends with a blink. In this case, blink offset will be defined as the last missing sample.)
        if isempty(blink_offset)
            blink_offset = size(pupil_data, 1);
        end;
        
        % Set the onset to be equal to the previous offset in case where several sets of missing values are presented consecutively
        if (sampling_interval*blink_onset > gap_interval && sampling_interval*blink_onset-sampling_interval*prev_offset<=gap_interval)
            blink_onset = prev_offset;
        end;
        
        prev_offset = blink_offset-1;
        % insert the onset into the result array
        working_blinks_data_positions(blink-2) = (blink_onset); %*sampling_interval
        % insert the offset into the result array
        working_blinks_data_positions(blink-1) = (blink_offset)-1; %*sampling_interval;
    end;
    
    %% Removing duplications (in case of consecutive sets): [a, b, b, c] => [a, c]
    [n, bin] = histc(abs(working_blinks_data_positions), unique(abs(working_blinks_data_positions)));
    multiple = find(n > 1);
    
    % In cases where there are an odd number of identical points, preserves
    % one of the points: [a, b, b, b] => [a, b]
    keepindex = [];
    for i = 1:length(n)
        if n(i) > 1 && mod(n(i),2) >0
            keepindex = vertcat(keepindex,find(bin==i,1));
        end
    end
    index = find(ismember(bin, multiple));
    index = index(~ismember(index,keepindex));
    working_blinks_data_positions(index) = [];
    
    %% Remove blink positions that are outside blink thresholds (min/max)
    non_blink_index = []; %initialize non_blink_index
    for i = 1:(length(working_blinks_data_positions)/2)
        if working_blinks_data_positions(2*i)-working_blinks_data_positions(2*i-1) < blink_length_min ...
                || working_blinks_data_positions(2*i)-working_blinks_data_positions(2*i-1) > blink_length_max
           non_blink_index = vertcat(non_blink_index,2*i-1,2*i);
        end
    end
    working_blinks_data_positions(non_blink_index) = [];
    
    %% Create final cleaned data array. Column 1 = blink start, Column 2 = blink end
    blinks_data_positions = zeros(length(working_blinks_data_positions)/2,2);
    for i = 1:(length(working_blinks_data_positions)/2)
        blinks_data_positions(i,1) = working_blinks_data_positions(2*i-1);
        blinks_data_positions(i,2) = working_blinks_data_positions(2*i);
    end
end