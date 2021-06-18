%% batch_process
% Script processes data for all folders listed in participantList.csv (must
% be located in same folder as data (inFilePath).

% assumes that data{} and dataCol.() have already been created by
% read_et_data.m. There should already be a folder for each participant in
% inFilePath

clc
clear
%% set paths
% For paths to set correctly, must by in "fractal-eye-analyses" folder
[s, e]=regexp(pwd, 'fractal-eye-analyses');
rootDir = pwd; 
rootDir = rootDir(1:e);

addpath(genpath(rootDir));
inFilePath = [rootDir '/data/'];
aoiPath = [rootDir '/data/dynamic_aoi/'];
%%
files = dir(inFilePath);
dirFlags = [files.isdir];
files = files(dirFlags);
log = cell(size(files,1), 2);
%%
for p = 1:size(files,1)
    %% clear workspace & set up output directory
    id = files(p).name;
    disp(['Attempting to read in data for ' id]);
    
    [success] = process_individual(id);
    log{p,1} = id;
    log{p,2} = success;
    
end


%%
save([inFilePath 'batch_process_log.mat'], 'log');   % save log
