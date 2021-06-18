# This script reformats the output from calibration.py to make it easier to work with long-formatted data. 
# Written by robinsifre, robinsifre@gmail.com
import csv
import os
import math
import datetime
import pandas as pd
import numpy as np
import sys
########################################
# Functions
#######################################

def return_first_id(fname):
	# Function returns first row, before header, which has the ID of the first participant
	df = pd.read_csv(fname, header = 0)
	return list(df.columns.values)[0]

# find row where new participant data starts 
def find_new_participant_row(df):
	col1 = df.iloc[:,0]# Participant ID always in the first col
	id_index = ~col1.str.contains('Left|Right|Bottom|Center|Top|Average|Number|Stimulus') #Entries without these words will be participant IDs
	indices = list(id_index[id_index==True].index)
	return indices

def pull_participant_data(df_slice):
	# pull id and remove from df_slice
	id_ind = find_new_participant_row(df_slice)
	partic = df_slice.Stimulus[id_ind[0]]
	df_slice = df_slice.drop(id_ind[0])
	df_slice.index=range(len(df_slice))
	# Remove rows that have summary data 
	ind_to_keep = ~df_slice.Stimulus.str.contains('Number|Average') 
	df_slice=df_slice.loc[ind_to_keep]
	# set index to participant name 
	df_slice.index=[partic]*len(df_slice)
	return df_slice

filename = sys.argv[1]
#filename = '/Users/sifre002/Box/sifre002/9_ExcelSpreadsheets/Dancing_Ladies/CalVer_output/DL1_output.csv'
base_name = os.path.basename(filename)
base_name = os.path.splitext(base_name)[0]

dir_name = os.path.dirname(filename)
print('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -')
print('Reformatting data, input file =' + filename)
print('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -')

########################################
# Read data 
#######################################

# Check that file type is either a .csv or .tsv
if(filename[-3:] != "csv" and filename[-3:] != "tsv"):
	print("Found non .tsv/.csv file: \n" + filename + "\n terminating script")
	quit()
	

# Read in file
if(filename[-3:]=="csv"):
	df = pd.read_csv(filename, header=1)
else:
	df = pd.read_csv(filename, header=1, delimiter='\t')

# Rename columns for easier programming
df = df.rename(columns={'Min Euclidean dist. (degrees)': "MinDist", 
					'Coordinates X': 'CoordX',
					'Coordinates Y': 'CoordY',
					'Duration (ms)': 'Dur',
					'Precision SD X': 'PrecSDx',
					'Precision SD Y': 'PrecSDy',
					'Precision RMS X': 'PrecRMSx',
					'Precision RMS Y': 'PrecRMSy'})

# Add first ID back in
partic_id = return_first_id(filename)
temp = pd.DataFrame([[partic_id, np.nan,np.nan,np.nan,np.nan,np.nan,np.nan,np.nan,np.nan]], columns=list(df.columns))
df = temp.append(df, ignore_index = True)

# Remove all the sub-headers
df=df.loc[~df.Stimulus.str.contains('Stimulus'), :]
df.index=range(len(df))

########################################
# Reformat 
#######################################

# Loop through DataFrame and reformat data. Save in <output>.
output = pd.DataFrame(columns={"Stimulus", "MinDist", "CoordX","CoordY", "Dur", "PrecSDx", "PrecSDy", "PrecRMSx", "PrecRMSy"})
partic_indices =  find_new_participant_row(df)
for i in range(0, len(partic_indices)-1):
	if i==len(partic_indices): # special case - last participant in spreadsheet
		data_slice=df.iloc[partic_indices[i]:df.shape[0]] 
	else:
		data_slice=df.iloc[partic_indices[i]:partic_indices[i+1]]
	output=output.append(pull_participant_data(data_slice),sort=True)

########################################
# Save
#######################################
{dir_name + "/" + base_name + "_reformatted.csv"}
output.to_csv (dir_name + "/" + base_name + "_reformatted.csv", index = True, header=True)






