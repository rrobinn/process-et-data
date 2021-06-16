function [success] = process_individual(path, varargin)
%% process_individual
%  processes data for one individual. Useful for parallelizing jobs

% assumes that data{} and dataCol.() have already been created by
% read_et_data.m. There should already be a folder for each visit in
% inFilePath
success = 0;


%% set paths
% For paths to set correctly, must by in "fractal-eye-analyses" folder
[s, e]=regexp(pwd, 'fractal-eye-analyses');
rootDir = pwd;
rootDir = rootDir(1:e);

addpath(genpath(rootDir));
aoiPath = [rootDir '/dynamic_aoi/'];


%%
% read in bounding boxes & make data structure of bounding boxes
[master_AOI, aoi_headers] = read_AOI(aoiPath);
[aoiStruct] = make_aoi_struct(master_AOI, aoi_headers);

%%
%% clear workspace & set up output directory
disp(['Attempting to read in data for ' path]);

% Get a list of the files
myDir = dir(path);
files = {myDir.name};
f = files(contains(files, 'RawData.mat')); % Should only be one match
f= f{1};

if isempty(f) 
    disp('Did not find _RawData.mat');
    return
end

%% % Load raw et data
fullPath =  [path, '/', f];
% get id
temp=strsplit(f, '_');
id = [temp{1}, '_', temp{2}, '_', temp{3}];

try
    %% Reading in et data
    load(fullPath);
    %% %% Flag Blinks
    disp(' ');
    disp(['----------------------------------------']);
    disp('Identify Blinks');
    pup = [cell2mat(data(:, dataCol.pupL))     cell2mat(data(:, dataCol.pupR))];
    pup(pup==-9999) = NaN;
    pup = mean(pup, 2, 'omitnan');
    pup(isnan(pup)) = 0;
    blinksPositions = blinkDetection(pup,300);
    
    % Fill BlinkBool Column with 1 for blinks
    data(:,size(data,2)+1) = {0};
    for i = 1:size(blinksPositions,1)
        data(blinksPositions(i,1):blinksPositions(i,2), size(data,2) ) = {1};
    end
    % update dataCol field
    dataCol.blink = size(data, 2);
    
    %% Parse data into trials
    disp('Parse trials');
    [PrefBin, ParticData] = parse_et_totrials(id, data, dataCol);
    %% Interpolate data
    disp('Interpolate missing data');
    plotFlag = 0;
    [propInterpolated, ParticData, PrefBin] = interpolate_data(ParticData, PrefBin, plotFlag, dataCol, 'strict');
    
    %% Flag fixations on Aois (based on interpolated data)
    [ParticData, PrefBin] = add_fix_faces(ParticData, PrefBin,aoiStruct);
    
    % Save  data
    disp('Save data & interpolated data & aoi data');
    save([path '/' id '_Parsed'], 'ParticData', 'PrefBin');
    %% dl time series
    disp('Create time series');
    [segmentedData,segSummaryCol]  = generate_timeseries(ParticData, PrefBin, dataCol);
    disp('Saving segmented data');
    save([path '/' id '_segmentedTimeSeries'],'segmentedData', 'segSummaryCol');
    
    %% calver time series
    disp('Make calver time series');
    [segmentedData_calVer, calVerCol] = generate_timeseries_calver(PrefBin, ParticData, dataCol);
    disp('Saving CalVer time series');
    save([path '/' id '_calVerTimeSeries'],'segmentedData_calVer', 'calVerCol');
    %%
    success = 1;
    disp([id ' finished!']);
catch ME
    disp([ME.identifier ' ' id])
    return
end


%%
