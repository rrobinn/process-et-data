function [aoiStruct] = make_aoi_struct(master_AOI, aoi_headers)

    % make struct of column names. Makes code easier to read.
    aoicol = struct();
    aoicol.movie = find(strcmpi('movie', aoi_headers));
    aoicol.frame = find(strcmpi('frame', aoi_headers));
    aoicol.lady = find(strcmpi('lady', aoi_headers));
    aoicol.x_start = find(strcmpi('x_start', aoi_headers));
    aoicol.x_end = find(strcmpi('x_end', aoi_headers));
    aoicol.y_start = find(strcmpi('y_start', aoi_headers));
    aoicol.y_end = find(strcmpi('y_end', aoi_headers));
    %% define the corners for each aoi (3 AOIs per frame)
    x1 = master_AOI(:, aoicol.x_start); % start
    x2 = master_AOI(:, aoicol.x_end); % end
    x3 = x2; %start
    x4 = x1; % end

    y1 = master_AOI(:, aoicol.y_start); % start
    y2 = y1; % start
    y3 = master_AOI(:, aoicol.y_end); % start
    y4 = y3;
    % vertices for aois
    xv = [x1 x2 x3 x4];
    yv = [y1 y2 y3 y4];
    %% break up aoi information for each movie & generate time stamps for each aoi (each frame = 40 ms)
    aoiStruct = struct();
    aoiStruct.movie = [1:5]';
    aoiStruct.xvertices = cell(5,3);
    aoiStruct.yvertices = cell(5,3);

    for movie = 1:5
        movieLogic = master_AOI(:, aoicol.movie) == movie;
        for lady = 1:3
            ladyLogic = master_AOI(:, aoicol.lady) == lady;
            aoiStruct.xvertices{movie, lady} = xv(movieLogic & ladyLogic, :);
            aoiStruct.yvertices{movie, lady} = yv(movieLogic & ladyLogic, :);
        end

    end
    % makes sure that the sizes are the same
    samples = cellfun(@(x) size(x,1), aoiStruct.xvertices, 'UniformOutput', false);
    samples = cell2mat(samples);

    if ~( isequal(samples(:,1), samples(:,2)) ) | ~( isequal(samples(:,1), samples(:,3)) ) | ~( isequal(samples(:,3), samples(:,2)) )
        error('Different number of frames for each lady in a movie');
    end

    aoiStruct.timeStamps = arrayfun(@(x) [40:40:x*40]', samples(:,1), 'uniformoutput', false);