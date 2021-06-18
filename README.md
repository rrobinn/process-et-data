Processing scripts for eye-tracking data.
# Overview
This folder contains code for processing raw eye-tracking data for the **Dancing Ladies** and **Calibration Verification** tasks, and creating time series for MFDFA analysis.  

Broadly, this involves extracting the (x,y) coordinates of where the infant is looking, and creating a 1-dimensional time series of the amplitude of the infant's gaze.  
<img src="https://github.com/rrobinn/fractal-eye-analyses/blob/master/images/xy_coord.png" alt="(x,y) coordinates" width="260" height="150">
<img src="https://github.com/rrobinn/fractal-eye-analyses/blob/master/images/amplitude.png" alt="Amplitude" width="260" height="150">

`process_individual.m` contains a "master script" that calls each function needed to create the time series for DFA.  Broadly, the processing steps include:  
1. <b>Flagging blinks</b> (`blinkDetection.m`)  
2. <b>Separating continuous stream of data into trials </b> (`parse_et_totrials.m`)  
3. <b>Interpolate missing data </b> (`interpolate_data.m`).  
4. <b>Flag samples where gaze coordinate falls in area of interest </b> (`add_fix_faces.m`; see **Data processing for face-looking analyses** for more info) 
5. <b> Parse each trial into multiple time series </b> (`generate_timeseris.m` and `generate_time_series_calver.m`)  

# How to run  
Broadly, there are 3 steps.  
1) `prep_tobii_output_individual.R`.  This converts the raw .tsv to a .txt file that is more readable by matlab.  
2) `read_et_data_individual.mat`. This reads the output from step 1, and converts it to a .mat file.  
3) `process_individual.mat`.  This calls all of the functions listed above, and process the .mat file with the raw data.  

Each of these functions is called on an individual eye-tracking visit, so that users can parallelize this if they are using an HCP environment. For example, if the path to your data is `~/process_et_data/data/JE000053_03/v01/EU-AIMS_counter_1`, then you would call the functions in the following order:  
`prep_tobii_output_individual('~/process-et-data/data/JE000053_03/v01/EU-AIMS_counter_1/')`  
`read_et_data_individual('~/process-et-data/data/JE000053_03/v01/EU-AIMS_counter_1/')`  
`process_individual('~/process-et-data/data/JE000053_03/v01/EU-AIMS_counter_1/')`   

# Data processing for face-looking analyses  
Some of these analyses are specific to the movies that we use. Namely, we are interested in how much time infants look at the faces in these movies.  
1. <b>Reading in .csv that contains the dynamic Areas of Interest (AOIs).</b> (`read_AOI` and `make_aoi_struct`) Because this a movie, the bounding boxes framing the faces change in each frame.  
2. <b>Determining if infant is looking at a face</b> (`add_fix_faces`). Flags each sample with a 1 if the gaze-positions falls within a face bounding box.

# Overview of output data structure  
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

# Calibration verification  
To collect good eye-tracking data, we must calibrate the infant to the eye-tracker. `calibration.py` calculates metrics assessing the quality of each infant's calibration. `reformat_calibration_verification.py` reformats the output to make it easier for merging with long data.
