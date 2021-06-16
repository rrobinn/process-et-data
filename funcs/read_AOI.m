function [master_AOI, headers] = read_AOI(inFilePath)
%% Function takes reads all .csv's that contain dynamic AOIs in inFilePath. Dynamic AOIs are defined separately for each movie. 
% Areas of Interest (AOI) in this study are the faces of each person. They
% are defined for each person, for each movie frame. The bounding boxes can
% be found in /data/dynamic_aoi. 

csvs = dir([inFilePath '*.csv']); % List of .csvs in the directory
csvs = {csvs.name};

master_AOI = [];
for c = 1:length(csvs)
    myfile = [inFilePath csvs{c}];
    fid = fopen(myfile);
    if fid == -1
        disp('');
        disp(['File containing AOIs: ' file '  does not exist']);% end program
        return
    end
    % read bounding boxes and formats 
    readInData = textscan(fid, '%f%f%f%f%f%f%f%f', 'HeaderLines', 1, 'Delimiter',',','EmptyValue',-Inf);
    data = [readInData{1} readInData{2} readInData{3} readInData{4} ...
        readInData{5} readInData{6} readInData{7} readInData{8}];
    fclose(fid);
    if c == 1
        % headers
        fid = fopen(myfile);
        headers = textscan(fid, '%s%s%s%s%s%s%s%s', 'Delimiter',',','MultipleDelimsAsOne', 1);
        headers = cellfun(@(x) x{1}, headers, 'UniformOutput', false);
    end
    master_AOI = vertcat(master_AOI, data);
end

end
