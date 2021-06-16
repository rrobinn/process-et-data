function [PrefBin, ParticData] = parse_et_totrials(id, data, dataCol)
% Function goes thru raw et data, and separates data into trials based on
% tobii output. 
ParticData = struct(); 
PrefBin = struct();
%% Get participant ID , date, etc.
a = strsplit(id, '_');
ParticipantName = [a{1}, '_', a{2}];

SessionNumber = a{3}; 
TimeOfDataCollection = data{1, dataCol.date};
%% parse events
thisParticClips = {};
thisParticData = {};

% get rid of rows with duplicate time stamps (small proportion of
% calibration verification data)
a = diff(cell2mat(data(:, dataCol.timestamp)));
dupLogic = a == 0; 
data = data(~dupLogic, :); 

currStamp = data{1, dataCol.timestamp};
count = 1; % count which eye-tracking trial script is on
while currStamp < data{size(data,1), dataCol.timestamp}
    % Pull data from trial
    disp(['Trial = ' num2str(count)]);
    currIdx = find(cell2mat(data(:, dataCol.timestamp)) == currStamp, 1);
    currEvent = data{currIdx, dataCol.media};
    
    % Pull data from curr Idx:end 
    temp = data(currIdx:size(data,1), :);
    
    % Find the row at which a new event starts
    out = cellfun(@(x) strcmpi(x, currEvent), temp(:, dataCol.media), 'uniformoutput', false); 
    out = cell2mat(out);
    changeIdx = diff(out);
    lastEventInd = find(changeIdx, 1, 'first');
    
    if ~isempty(lastEventInd)
        thisParticData{count, 1} = temp(1:lastEventInd, :);
        thisParticClips{count, 1} = currEvent;
        
        currStamp = temp{lastEventInd + 1, dataCol.timestamp}; % time stamp
        count = count + 1;
    else % last event
        thisParticData{count, 1} = temp(:, :);
        thisParticClips{count, 1} = currEvent;
        currStamp = data{size(data,1), dataCol.timestamp};
    end
end


PrefBin.ParticipantName = ParticipantName;
PrefBin.SessionNumber = SessionNumber;
PrefBin.MovieListAsPresented = thisParticClips(~strcmpi('-9999', thisParticClips)); % trials separated by -9999. Remove these.
PrefBin.TimeOfTallying = date;
PrefBin.TimeOfDataCollection = TimeOfDataCollection;
ParticData.Data = thisParticData(~strcmpi('-9999', thisParticClips)); % trials separated by -9999. Remove these.



