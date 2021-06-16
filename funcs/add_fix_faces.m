
function [ParticData, PrefBin] = add_fix_faces(ParticData, PrefBin, aoiStruct)
%% add_fix_faces: function flags each eye-tracking frame with a 1 if eye-gaze (x,y) coordinate falls within a face boudning box.
    %% Hard-coded variables
    trialList = {'01_converted.avi', '01S_converted.avi', ...
        '03_converted.avi', '03S_converted.avi', ...
        '04_converted.avi', '04S_converted.avi', ...
        '05_converted.avi', '05S_converted.avi'};
for t = 1:length(PrefBin.MovieListAsPresented)
    
    if ~isempty( intersect(PrefBin.MovieListAsPresented{t}, trialList) ) % AOIs needed
        %% Pull interpolated data for this movie
        %which movie did they see
        movie = regexp(PrefBin.MovieListAsPresented{t}, '\d');
        movie = PrefBin.MovieListAsPresented{t}(movie);
        movie = str2num(movie);
        
        % pull interpolated data from this movie
        currData = ParticData.Data{t,2};
        currTime = cell2mat( ParticData.Data{t,1}(:,1) );
        currTime = double(currTime - currTime(1,1));
        
        %% find closest AOI index for each sampled ET frame
        % (time stamps might be off by +/- 1ms)
        aoiTime = aoiStruct.timeStamps{movie,1};
        A = repmat(aoiTime,[1 length(currTime)]);
        A = double(A);
        [minValue, closestIndex] = min(abs(A-currTime'));
        closestIndex = closestIndex';
        %%
        aoi_hit = zeros(size(currData,1),3);  % 3 potential faces in each frame
        for a = 1:size(currData,1) % for each row of data
            if currData(a,1) == -9999
                aoi_hit(a, 1:3) = -9999;
            else
                aoiIdxToCheck = closestIndex(a);
                for l = 1:3 % for each of the three potential faces
                    % pull the AOI for this frame
                    xv_temp = aoiStruct.xvertices{movie, l}(aoiIdxToCheck, :);
                    yv_temp = aoiStruct.yvertices{movie, l}(aoiIdxToCheck, :);
                    % check if data fell into aoi
                    in = inpolygon(currData(a,1), currData(a,2), xv_temp, yv_temp);
                    aoi_hit(a, l) = in;
                end
            end
        end
        aoi_str = zeros(size(aoi_hit,1), 1);
        aoi_str(aoi_hit(:,1) == 1) = 1;
        aoi_str(aoi_hit(:,2) == 1) = 2;
        aoi_str(aoi_hit(:,3) == 1) = 3;
        aoi_str(aoi_hit(:,1) == -9999) = -9999;
        
        ParticData.Data{t,3} = aoi_str;
    end % end trial
    
end