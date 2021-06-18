# Robin Sifre - robinsifre@gmail.com
# Reading mixed data into Matlab can be a pain - script preps tobii output for Matlab import
# This version does it for one individual for parallel processing 
prep_tobii_output_individual <- function(f, overwrite = NULL) {
  # f = full path to directory with .tsv (e.g. JE123456_03_01_CalibrationVerification)
  # overwrite = 1/0 indicating whether you should over-write a .txt file if one is already in the directory f
  require(dplyr)
  require(assertr)
  
  # By default, do not over-write the .txt file 
  if (is.null(overwrite)) overwrite = 0
  
  # # Columns needed for analysis
  # necessary_cols = c('RecordingTimestamp', 'ParticipantName', 'RecordingResolution',
  #                    'GazePointLeftX..ADCSpx.','GazePointLeftY..ADCSpx.','PupilLeft','ValidityLeft',
  #                    'GazePointRightX..ADCSpx.', 'GazePointRightY..ADCSpx.', 'PupilRight', 'ValidityRight',
  #                    'MediaName', 'RecordingDate', 'RecordingDuration')
  
  all_cols = c('RecordingTimestamp','ParticipantName','RecordingResolution','GazePointLeftX..ADCSpx.',
               'GazePointLeftY..ADCSpx.','DistanceLeft','PupilLeft','ValidityLeft',
               'GazePointRightX..ADCSpx.','GazePointRightY..ADCSpx.',
               'DistanceRight','PupilRight','ValidityRight',
               'FixationIndex','GazePointX..ADCSpx.','GazePointY..ADCSpx.','GazeEventDuration',
               # Info about trials
               'MediaName','StudioProjectName','RecordingDate', 'RecordingDuration')
  
  action = ''
  
  #id = basename(f)
  
  temp = list.files(f)
  filename = temp[grepl(pattern = 'tsv', temp)] # Files with dancing ladies data 
  n_files = length(filename)
  
  if (n_files==0) {
    action = 'No .tsv match - skipped'
    return(action) 
  }
  
  cleaned_dat = list()
  for (i in c(1:n_files)) {
    fname =filename[i]
    bname = gsub('\\.tsv', '', fname) 
    
    # Check if the .txt file already exists 
    if ( file.exists(paste(f, '/',bname,'.txt', sep='')) & overwrite==0 ) {
      action = '.txt file already exists - skipped'
      return(action)
    }
    
    # If this is not the first file, check to see if this is an accidental copy
    if (i!=1) {
      temp =  read.delim(paste(f, fname, sep = '/'), sep = '\t', stringsAsFactors = FALSE, nrow=1)
      if (temp$RecordingDuration == cleaned_dat[[i=1]]$RecordingDuration[1]) next 
    }
    
    # Otherwise, read data 
    dat=read.delim(paste(f, fname, sep = '/'), sep = '\t', stringsAsFactors = FALSE)
    # Check if it imported as one col
    #if (dim(dat)[2]==1){
    #  dat=read.delim(paste(f, filename, sep = '/'), sep = ',', stringsAsFactors = FALSE)
    #}
    # Check if it has all the headers needed
    missing_cols = all_cols[!all_cols %in% colnames(dat)]
    if (length(missing_cols)>0) {
      missing_cols = paste(missing_cols, collapse = ',')
      action = paste('misisng cols: ', missing_cols)
      return(action)
    }
    
    # Select the columns that you do have 
    dat2 = dat %>% 
      dplyr::select( all_of(all_cols))
    # Get rid of .. in colnames
    colnames(dat2) = gsub(pattern = '\\.', replacement='', colnames(dat2))
    
    
    # Handle empty cols
    for (c in colnames(dat2)) {
      if ( is.character(dat2[, c]) ) {
        dat2[, c] = ifelse(dat2[, c] == '', '-9999', dat2[, c])
      }
      if (is.numeric(dat2[, c])) {
        dat2[, c] = ifelse(is.na(dat2[,c]), -9999, dat2[, c])
      }
    }
    # Handle time stamp formatting 
    if (grepl(':', dat2$RecordingTimestamp[1])){ # If it's in the HH:MM:SS.XX format 
      dat2 = dat2 %>% 
        mutate(RecordingTimestamp = hms(dat2$RecordingTimestamp),
               RecordingTimestamp = seconds(RecordingTimestamp))
      
      dat2$RecordingTimestamp = dat2$RecordingTimestamp  - dat2$RecordingTimestamp[1]
      dat2$RecordingTimestamp = as.numeric(dat2$RecordingTimestamp)*1000
    }

  
    # Generate text to write to .txt file 
    colnames = paste(colnames(dat2), collapse = ',')
    cleaned_dat[[i]] = dat2

  } # End for loop
  
  
  if (length(cleaned_dat)==1) {
    to_print = cleaned_dat[[1]]
    to_print=col_concat(to_print, sep = ',')
  }else{
    # Get last time stamp of the first file 
    ts1 = cleaned_dat[[1]]$RecordingTimestamp
    ts1 = ts1[length(ts1)]
    
    # Get first time stamp of the second file
    ts2 = cleaned_dat[[2]]$RecordingTimestamp
    ts2 = ts2[1]
    
    # For the second file (which is arbitrary) set the first time stamp to 0, then add ts2 + 1
    cleaned_dat[[2]]$RecordingTimestamp  = cleaned_dat[[2]]$RecordingTimestamp - cleaned_dat[[2]]$RecordingTimestamp[1] # Set to 0
    cleaned_dat[[2]]$RecordingTimestamp = cleaned_dat[[2]]$RecordingTimestamp + ts1 + 1
    
    to_print = rbind(cleaned_dat[[1]], cleaned_dat[[2]])
    to_print=col_concat(to_print, sep = ',')
    action = paste(action, 'concatenated 2 files ...')
    }
  
  
  
  action = paste(action, '...success')
  write.table(x=to_print, file = paste(f, '/', bname, '.txt', sep='' ), col.names=FALSE, row.names = FALSE, eol = '\n')  
  write.table(x=colnames, file = paste(f, '/', bname, '_colnames.txt', sep =''), row.names=FALSE, col.names=FALSE)
  return(action)

}







