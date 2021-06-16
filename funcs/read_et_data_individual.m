function [success] = read_et_data_individual(fileDir, varargin)
%% Reads in eye-tracking data from tobii. (Expects a .txt file, with corresponding colnames.txt)
% Individual version written for parallel processing
% Inputs:
% inFilePath = Path to parent directory that has sub-directories (one for each visit) containing
% the et data. Assumes that et data is in a .txt file, with the same name
% as the parent folder (e.g. JE123456_03_01/JE123456_03_01.txt)
%
% overwite - (Optional) 0/1 indicating whether to over-write .mat file if
% it already exists.

%% Check varargin
overwrite=1;
if nargin>1
    for v=1:2:length(varargin)
        switch varargin{v}
            case 'overwrite'
                overwrite=varargin{v+1};
            otherwise
                error(['Input ' varargin{v} 'not recognized']);
        end
    end
end

%% Read in data
cd(fileDir);
listfiles = dir(fileDir);
files = {listfiles.name};
dirs = {listfiles.folder};

logic = contains(files, 'txt') & ~contains(files, 'colnames');

files = files(logic);
dirs = dirs(logic);


disp(' ');
disp(['----------------------------------------']);
disp('Processing Data' );
success = {fileDir}; % log ID

for f=1:length(files)
    
    txtFileName = files{f}; % Name of .txt file script looks for
    baseName = txtFileName(1: find(txtFileName == '.') - 1);
    
    % look for participant name
    if ~isfile(txtFileName)
        success = strcat(success, ', No .txt file in directory');
        return;
    end
    
    % If there is already a .matfile called id_Rawdata.mat, and we're not
    % supposed to over-write, skip
    if isfile([baseName '_rawData.mat']) && ~overwrite
        success = strcat(success, ', Skipped - did not overwrite .mat file');
        return;
    end
    
    
    %% Import data
    disp(['Processing  ' txtFileName]);
    % .txt file with et data
    t = readtable(txtFileName);
    t=table2cell(t);
    t=cellfun(@(x) strsplit(x,','), t, 'UniformOutput',false);
    t=vertcat(t{:});
    
    % headers
    headers = importdata([baseName '_colnames.txt']);
    headers = strsplit(headers{1}, ',');
    
    %% Get the columns numbers from colnames.txt
    % Used for pulling the data from the .txt file
    txtCol = struct();
    txtCol.timestamp = find( cellfun(@(x) contains(x, 'RecordingTimeStamp', 'IgnoreCase', true), headers) );
    txtCol.id =find( cellfun(@(x) contains(x, 'ParticipantName', 'IgnoreCase', true), headers) );
    txtCol.date = find( cellfun(@(x) contains(x, 'RecordingDate', 'IgnoreCase', true), headers) );
    %
    txtCol.gazeLx = find( cellfun(@(x) contains(x, 'GazePointLeftX', 'IgnoreCase', true), headers) );
    txtCol.gazeLy = find( cellfun(@(x) contains(x, 'GazePointLeftY', 'IgnoreCase', true), headers) );
    txtCol.distL = find( cellfun(@(x) contains(x, 'DistanceLeft', 'IgnoreCase', true), headers) );
    txtCol.pupL = find( cellfun(@(x) contains(x, 'PupilL', 'IgnoreCase', true), headers) );
    txtCol.validityL = find( cellfun(@(x) contains(x, 'ValidityLeft', 'IgnoreCase', true), headers) );
    %
    txtCol.gazeRx = find( cellfun(@(x) contains(x, 'GazePointRightX', 'IgnoreCase', true), headers) );
    txtCol.gazeRy = find( cellfun(@(x) contains(x, 'GazePointRightY', 'IgnoreCase', true), headers) );
    txtCol.distR = find( cellfun(@(x) contains(x, 'DistanceRight', 'IgnoreCase', true), headers) );
    txtCol.pupR = find( cellfun(@(x) contains(x, 'PupilR', 'IgnoreCase', true), headers) );
    txtCol.validityR = find( cellfun(@(x) contains(x, 'ValidityRight', 'IgnoreCase', true), headers) );
    %
    txtCol.fixIdx = find( cellfun(@(x) contains(x, 'FixationIndex', 'IgnoreCase', true), headers) );
    txtCol.gazeX = find( cellfun(@(x) contains(x, 'GazePointX', 'IgnoreCase', true), headers) );
    txtCol.gazeY = find( cellfun(@(x) contains(x, 'GazePointY', 'IgnoreCase', true), headers) );
    %
    txtCol.media = find( cellfun(@(x) contains(x, 'MediaName', 'IgnoreCase', true), headers) );
    txtCol.gazeEventType = find( cellfun(@(x) contains(x, 'GazeEventType', 'IgnoreCase', true), headers) );
    txtCol.gazeEventDur = find( cellfun(@(x) contains(x, 'GazeEventDuration', 'IgnoreCase', true), headers) );
    txtCol.saccIdx =find( cellfun(@(x) contains(x, 'SaccadeIndex', 'IgnoreCase', true), headers) );
    txtCol.saccAmp = find( cellfun(@(x) contains(x, 'SaccadicAmplitude', 'IgnoreCase', true), headers) );
    txtCol.project =find( cellfun(@(x) contains(x, 'StudioProjectName', 'IgnoreCase', true), headers) );
    txtCol.recordingres = find( cellfun(@(x) contains(x, 'RecordingResolution', 'IgnoreCase', true),headers));
    
    %% Save in right columns
    data = cell(size(t,1), numel(fieldnames(txtCol))); % pre-allocate output
    
    if ~isempty(txtCol.timestamp) data(:,1) = t(:, txtCol.timestamp); end;
    if ~isempty(txtCol.id) data(:,2) = t(:, txtCol.id); end;
    if ~isempty(txtCol.date) data(:,3) = t(:, txtCol.date); end;
    if ~isempty(txtCol.gazeLx) data(:,4) = t(:, txtCol.gazeLx);end;
    if ~isempty(txtCol.gazeLy) data(:,5) = t(:, txtCol.gazeLy);end;
    if ~isempty(txtCol.pupL) data(:,6) = t(:, txtCol.pupL);end;
    if ~isempty(txtCol.distL) data(:,7) = t(:, txtCol.distL);end;
    if ~isempty(txtCol.validityL)  data(:,8) = t(:, txtCol.validityL);end;
    
    if ~isempty(txtCol.gazeRx) data(:,9) = t(:, txtCol.gazeRx);end;
    if ~isempty(txtCol.gazeRy) data(:,10) = t(:, txtCol.gazeRy);end;
    if ~isempty(txtCol.pupR) data(:,11) = t(:, txtCol.pupR);end;
    if ~isempty(txtCol.validityR) data(:,12) = t(:, txtCol.validityR);end;
    if ~isempty(txtCol.distR) data(:,13) = t(:, txtCol.distR);end;
    %
    if ~isempty(txtCol.fixIdx) data(:,14) = t(:, txtCol.fixIdx); end;
    if ~isempty(txtCol.gazeX) data(:,15) = t(:, txtCol.gazeX); end;
    if ~isempty(txtCol.gazeY) data(:,16) = t(:, txtCol.gazeY); end;
    
    if ~isempty(txtCol.media) data(:,17) = t(:, txtCol.media); end;
    if ~isempty(txtCol.gazeEventType) data(:,18) = t(:, txtCol.gazeEventType); end;
    if ~isempty(txtCol.gazeEventDur) data(:,19) = t(:, txtCol.gazeEventDur); end;
    if ~isempty(txtCol.saccIdx) data(:,20) = t(:, txtCol.saccIdx); end;
    if ~isempty(txtCol.saccAmp) data(:,21) = t(:, txtCol.saccAmp); end;
    if ~isempty(txtCol.project) data(:,22) = t(:, txtCol.project); end;
    if ~isempty(txtCol.recordingres) data(:,23) = t(:, txtCol.recordingres); end;
    
    %% Make struct of datacols to save in .mat file
    dataCol = struct();
    dataCol.timestamp=1;
    dataCol.id=2;
    dataCol.date=3;
    dataCol.gazeLx = 4;
    dataCol.gazeLy=5;
    dataCol.pupL=6;
    dataCol.distL=7;
    dataCol.validityL=8;
    %
    dataCol.gazeRx=9;
    dataCol.gazeRy=10;
    dataCol.pupR=11;
    dataCol.validityR=12;
    dataCol.distR=13;
    %
    dataCol.fixIdx=14;
    dataCol.gazeX=15;
    dataCol.gazeY=16;
    
    dataCol.media=17;
    dataCol.gazeEventType=18;
    dataCol.gazeEventDur=19;
    dataCol.saccIdx=20;
    dataCol.saccAmp=21;
    dataCol.project=22;
    dataCol.recordingres=23;
    %% to save time later, convert important columns to numbers
    % fix the time
    
    data(:, dataCol.timestamp) = num2cell( cellfun(@(x) str2num(x), data(:, dataCol.timestamp)) );
    data(:, dataCol.pupL) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.pupL)) );
    data(:, dataCol.validityL) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.validityL)) );
    data(:, dataCol.pupR) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.pupR))) ;
    data(:, dataCol.validityR) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.validityR))) ;
    data(:, dataCol.gazeX) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.gazeX)) );
    data(:, dataCol.gazeY) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.gazeY)) );
    data(:, dataCol.gazeLx) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.gazeLx)) );
    data(:, dataCol.gazeRx) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.gazeRx)) );
    data(:, dataCol.gazeLy) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.gazeLy)) );
    data(:, dataCol.gazeRy) =  num2cell( cellfun(@(x) str2num(x), data(:, dataCol.gazeRy)) );
    %% Remove rows where media = 999 (padding bw trials)
    
    save([baseName '_RawData.mat'], 'data', 'dataCol');
end
end
