Processing scripts for eye-tracking data.
# Overview
This folder contains code for processing raw eye-tracking data, and creating time series for MFDFA analysis. 
`process_individual.m` contains a "master script" that calls each function needed to create the time series for DFA. `batch_process.m` can be used to loop through many individuals.  Broadly, the processing steps include:  
1. <b>Flagging blinks</b> (`blinkDetection.m`)  
2. <b>Separating continuous stream of data into trials </b> (`parse_et_totrials.m`)  
3. <b>Interpolate missing data </b> (`interpolate_data.m`).  
4. <b>Flag samples where gaze coordinate falls in area of interest </b> (`add_fix_faces.m`) 
5. <b> Parse each trial into multiple time series </b> (`generate_timeseris.m` and `generate_time_series_calver.m`)  

# Calibration verification  
To collect good eye-tracking data, we must calibrate the infant to the eye-tracker. `calibration.py` calculates metrics assessing the quality of each infant's calibration. `reformat_calibration_verification.py` reformats the output to make it easier for merging with long date.

# Data processing for face-looking analyses  
Some of these analyses are specific to the movies that we use. Namely, we are interested in how much time infants look at the faces in these movies.  
1. <b>Reading in .csv that contains the dynamic Areas of Interest (AOIs).</b> (`read_AOI` and `make_aoi_struct`) Because this a movie, the bounding boxes framing the faces change in each frame.  
2. <b>Determining if infant is looking at a face</b> (`add_fix_faces`). Flags each sample with a 1 if the gaze-positions falls within a face bounding box.

# Overview of data structure  
## 1. `_Raw_data.mat`  
Contains a cell-array (`data`) that contains a continuous stream of eye-tracking data. Each row is a sample. Column headers can be found in the `dataCol` struct.  

## 2. `_Parsed.mat`.  
Contains 2 structs: `ParticData` and `PrefBin`.  
- ParticData is a cell-array. Each row corresponds to a movie that the infant saw.  
- <b>Column 1</b> holds the raw data. Each row is an eye-tracking sample. Column headers can be found in `_RawData.mat`.    
- <b>Column 2</b> holds the (x,y) coordinate data. Each row is an eye-tracking sample.   
- <b>Column 3</b> holds information on whether the child was looking at a face. -9999=missing data, 0=no faces, 1, 2, or 3=refers to the three faces on the screen (from left to right).  

## 3. `_segmentedTimeSeries.mat` and `_calVerTimeSeries.mat`.  
Contains the data segmented into time series.
