#!/usr/bin/python3
## Script for Dr. Kirsten Dalrymple <kad@umn.edu>,
## Originally written August 7, 2015 by Marie D Manner <manne044@umn.edu>
## Last updated on April 17, 2018 by Marie D Manner <manne044@umn.edu>
## Last updated on Jan 20, 2020 by Robin D Sifre <sifre002@umn.edu>
"""
This program sorts through eye tracking calibration data to find the
longest DURATION fixation point that is also LESS than 6 degrees
of visual angle.

If a participant looks at a fixation and it 'leaks' onto the next
fixation, that entire length of time is the fixation time, and
that 'leaked' time does not count for the next stimulus.

The user will choose an entire folder full files to evaluate; using eye
validity codes is preferred but you can also use without with no changes.

This will output a summary CSV and summary log file.  The CSV will contain
details on the longest fixation on each stimulus if available, such as
the minimum Euclidean distance from gaze to stimulus in degrees,
those coordinates, the duration, the precision standard deviation and
the RMS.  The summary log file will list files processed or skipped.

This runs in Python3.  See user manual for details.

This script requires header files in the csv script. Please add
them if they are not present. I expect something like:

  ParticipantName, RecordingDate,
  FixationFilter, MediaName, RecordingTimestamp, GazeEventDuration,
  GazePointX (ADCSpx), GazePointY (ADCSpx), ValidityLeft, ValidityRight,
  Recording

If you do NOT have validity codes (ValidityLeft and ValidityRight), this script
will assume all output was valid; if you do have validity codes, use them.

By using this program you agree that:
  - you are using it at your own risk,
  - it comes without programmer support,
  - and it may explode in a shower of code.
"""
## This requires at least python 3; it's been tested on Windows 10 with 3.5.1,
## as well as Ubuntu 14.04 with python 3.4.3.  If you want it to work on
## python 2, you'll need to remove the tkinter stuff and adapt it to a
## command line path for the folder.
##
## Copyright: 2016 Marie D Manner.  This code is distributed under the
## terms of the Creative Commons Attribution License, which permits noncommercial
## use, sharing, and adaptation and/or sharing that adapted material, provided
## that the original author and source are credited and you release your
## material under this same license.  See:
## Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)
## https://creativecommons.org/licenses/by-nc-sa/4.0/

################################################################################
## If you need to update values, do that here (e.g. verbosity mode or stimuli.
################################################################################
import csv
import os
import math
import datetime
import sys

verbose = False  # turn to False if you want it to print less.

# Locations of all stimulus. The user can change these.
locations = {  # "Fix.jpg": [960.0, 540.0],
    "TopLeft_converted.avi": [480.0, 270.0],
    "TopRight_converted.avi": [1440.0, 270.0],
    "Center_converted.avi": [960.0, 540.0],
    "BottomLeft_converted.avi": [480.0, 810.0],
    "BottomRight_converted.avi": [1440.0, 810.0]}

# This is used for printing the headers to the CSV file at the end.
header = [
    'Stimulus',
    # All for the longest fixation:
    'Min Euclidean dist. (degrees)',
    'Coordinates X',
    'Coordinates Y',
    'Duration (ms)',
    'Precision SD X',
    'Precision SD Y',
    'Precision RMS X',
    'Precision RMS Y']

################################################################################
## Import libraries; define functions.
################################################################################
if len(sys.argv) > 1:
    dirname = sys.argv[1]
else:
    from tkinter import Tk

    try:
        from tkinter.filedialog import askdirectory
    except:
        print("Error! Run this script with Python3 (e.g. python3.4).\nExiting.\n")
        exit()

    # Make sure the TK() window doesn't appear, and doesn't keep the askdirectory up
    root = Tk()
    root.withdraw()
    root.update()

print(__doc__)


def find_degree(scriptpix, tobiimm, userpix, usermm):
    """ For converting number of pixels to degree of visual angle.  The user
  needed to have input some of those values (screen resolution in MM and
  pixels) and some is from TOBII output. """
    t = math.atan(((scriptpix / 2.) / ((tobiimm * userpix) / usermm)))
    return (math.degrees(t) * 2.)


def find_rms(points):
    """For finding the Root Mean Square from points in a list;
  <points> is a non-zero list of (x, y) coords."""

    sx = 0.0  # sum all X coordinates
    sy = 0.0  # sum all Y coordinates

    for index in range(len(points) - 1):
        sx = sx + (points[index][0] - points[index + 1][0]) ** 2
        sy = sy + (points[index][1] - points[index + 1][1]) ** 2
    sx = math.sqrt(sx / len(points))
    sy = math.sqrt(sy / len(points))
    return [sx, sy]


def find_euclid_dist(pointa, pointb):
    """ For finding euclidean distance between a set of 2 points. """
    return (math.sqrt((pointa[0] - pointb[0]) ** 2 + (pointa[1] - pointb[1]) ** 2))


def find_ave_xy(points):
    """For finding the average set of points in a list.
  <points> is a non-zero list of (x, y) coords."""
    avex = sum([p[0] for p in points]) / len(points)
    avey = sum([p[1] for p in points]) / len(points)
    return [avex, avey]


# There is apparently already a module in lib 'statistics' in 3.4+
# but I don't have it and don't want to count on users having it.
def find_sd(points):
    """ For finding the standard deviation for a set of (x, y) coordinates
  stashed in <points>. """
    [avex, avey] = find_ave_xy(points)
    tempx = math.sqrt(sum([((p[0] - avex) ** 2) for p in points]) / len(points))
    tempy = math.sqrt(sum([((p[1] - avey) ** 2) for p in points]) / len(points))
    return [tempx, tempy]


################################################################################
## Print some information about the script.
################################################################################

print("Verbose mode is %s\n" % verbose)

################################################################################
## Script begins.
################################################################################
participant_distances = []  # will contain part. name + calculated mean distance from screen

# Choose folder with all cvs's in it
# dirname = askdirectory()
print("Using " + dirname)
print("Printing a script summary to <%s>." % (dirname + '_summary.txt'))
print("Printing results to file <%s>." % (dirname + '_output.csv'))

# We need the screen size resolution and millimeters to output in degrees.
mm_height, mm_width = -1., -1.
pix_height, pix_width = -1., -1.
usesame = False

try:
    with open("./calibrationvalues.txt", 'r') as oldvals:
        mm_height = float(oldvals.readline())
        mm_width = float(oldvals.readline())
        pix_height = float(oldvals.readline())
        pix_width = float(oldvals.readline())
    print("Do you want to use the same values from last time? \n\
  screen height (MM): %s\n\
  screen width (MM): %s\n\
  screen height (pixels): %s\n\
  screen width (pixels): %s\n\
You can say 'y', 'Y', 'yes', 'Yes', or anything else (e.g. 'n'):\n"
          % (mm_height, mm_width,
             pix_height, pix_width))
    usesame_response = input()
    if usesame_response.lower() in ['y', 'yes']:
        usesame = True
except:
    pass

if not usesame:
    mm_height = float(input("What is your screen *height* \
in millimeters? (e.g. 344): "))
    mm_width = float(input("What is your screen *width* in \
millimeters? (e.g. 594): "))
    pix_height = float(input("What is your screen *height* \
(resolution) in pixels? (e.g. 1080): "))
    pix_width = float(input("What is your screen *width* \
(resolution) in pixels? (e.g. 1920): "))
    # and rewrite the file
    with open("./calibrationvalues.txt", 'w') as newvals:
        newvals.write('%s\n' % mm_height)
        newvals.write('%s\n' % mm_width)
        newvals.write('%s\n' % pix_height)
        newvals.write('%s\n' % pix_width)

# Properly formatted, information-rich CSVs that got processed.
csv_names_processed = []
# Non .csv files that got skipped.
nonc_names_skipped = []
# Improperly formatted or information-lacking CSVs that did NOT get processed.
cvs_names_skipped = []

dirList = os.listdir(dirname)
dirList = sorted(dirList)

# Make directory for problem files
problem_dir = dirname + '_problemfiles'
if os.path.isdir(problem_dir) is False:
    os.mkdir(problem_dir)

print(dirList)



for file in dirList:

    print("*********************************************************")
    filename = dirname + "/" + file
    # build filename, open, and read...
    if (filename[-3:] != "csv" and filename[-3:] != "tsv"):
        print("Found non .tsv/.csv file: \n" + filename)
        nonc_names_skipped.append(filename)
        continue

    f = open(filename)
    if (filename[-3:] == "csv"):
        cf = csv.reader(f)
    else:
        cf = csv.reader(f, delimiter='\t')
    d = []

    print("Loading file %s..." % (filename))

    for row in cf:
        d.append(row)

    f.close()

    # Things I need to store per stimulus:
    # leakDuration["TopLeft.jpg"]["EuclideanDistance"] = 43.3  or whatever.
    # Euclidean distance, coordinates, length of time, SD, RMS.

    print("Done.\nBuilding data structures and finding the first fixation point... ")

    ########################################################
    # Process the first GOOD line in the file
    line = 0

    # Just find the index for the columns you care about, in
    # case we end up changing where the columns go again.
    # I assume the headers / row 0 is something like:
    # ParticipantName, RecordingDate, FixationFilter, MediaName, RecordingTimestamp,
    # FixationIndex, GazeEventDuration, GazePointX (ADCSpx), GazePointY (ADCSpx),
    # ValidityLeft, ValidityRight

    MediaName, RecordingTimestamp = -1, -1
    FixationIndex, GazeEventDuration = -1, -1
    GazePointX, GazePointY, ValidityLeft, ValidityRight = -1, -1, -1, -1
    DistanceLeft, DistanceRight = -1, -1  # Needed for outputting in degrees.
    ParticipantName = ""

    hasvalidity = True  # If you output ValidLeft and ValidRight columns.

    # will anyone want this case insensitive?
    for i in range(len(d[0])):
        if d[0][i] == "MediaName":
            MediaName = i
        elif d[0][i] == "ParticipantName":
            ParticipantName = d[1][i]  # just store the name; don't need index.
        elif d[0][i] == "RecordingTimestamp":
            RecordingTimestamp = i
        elif d[0][i] == "FixationIndex":
            FixationIndex = i
        elif d[0][i] == "GazeEventDuration":
            GazeEventDuration = i
        elif d[0][i] == "GazePointX (ADCSpx)":
            GazePointX = i
        elif d[0][i] == "GazePointY (ADCSpx)":
            GazePointY = i
        elif d[0][i] == "ValidityLeft":
            ValidityLeft = i
        elif d[0][i] == "ValidityRight":
            ValidityRight = i
        elif d[0][i] == "DistanceLeft":
            DistanceLeft = i
        elif d[0][i] == "DistanceRight":
            DistanceRight = i

    if -1 in [MediaName, RecordingTimestamp, FixationIndex, GazeEventDuration,
              GazePointX, GazePointY, DistanceLeft, DistanceRight]:
        print("************************* ERROR ************************* \n\
I didn't find some of the headers I was looking for. \
Please check that your headers include these: \
\nMediaName, RecordingTimestamp, FixationIndex, GazeEventDuration, \
GazePointX, GazePointY, \nValidityLeft, ValidityRight, DistanceLeft, \
DistanceRight \
and then run the script again (case-sensitive).\n\n\
Whichever of these values are -1 is a missing header:\n\
MediaName = %i \nRecordingTimestamp = %i\nFixationIndex = %i\n\
GazeEventDuration = %i\nGazePointX = %i\nGazePointY = %i\n\
ValidityLeft = %i\nValidityRight = %i\nDistanceLeft = %i\n\
DistanceRight = %i" % (MediaName, RecordingTimestamp, FixationIndex,
                       GazeEventDuration, GazePointX, GazePointY, ValidityLeft, ValidityRight,
                       DistanceLeft, DistanceRight))
        cvs_names_skipped.append(filename)
        print("Skipping file %s." % filename)
        continue

    if -1 in [ValidityLeft, ValidityRight]:
        print("************************* ERROR ************************* \n \
I didn't see columns for ValidityLeft or ValidityRight. If you have those,\n\
please re-export your data with those columns.  This script will continue,\
but I must assume\n\
all the data you've exported is considered valid for one / both eyes.\n")
        hasvalidity = False

    if verbose:
        print("Finding participant's average distance from screen...")

        # Handle versions with key events (duplicate time stamps)
    i = 1
    time = d[1][RecordingTimestamp]
    while i < len(d) - 1:  # Remove row with dup time stamp
        temp = d[i][RecordingTimestamp]
        if temp == '-9999' or temp == '':
            i = +1
        elif temp != time:
            time = temp  # update time
            i += 1
        else:  # If this row is the same time stamp as the one before, remove it
            r = d.pop(i)
            i += 1

    distLefts = []
    distRights = []
    # Can't use Pandas to import; it floats() them too hard, e.g. 123.01
    # becomes 123.0000000001.
    for i in range(1, len(d)):
        distLefts.append(d[i][DistanceLeft])
        distRights.append(d[i][DistanceRight])

    newL = []
    newR = []
    for i in range(len(distLefts)):
        try:
            if distLefts[i] in ['', ' ', '0', '-9999']:
                pass
            elif distRights[i] in ['', ' ', '0', '-9999']:
                pass
            else:
                newL.append(float(distLefts[i]))
                newR.append(float(distRights[i]))
        except:
            print("Something went wrong slurping distance left <%s> and distance right <%s>" % (
            distLefts[i], distRights[i]))
            exit()

    if len(newL) != len(newR):
        print("Something went wrong finding average of distance from screen!")
        exit()

    if len(newL) ==0:
        print("No data - moving to problem directory")
        # Move file to /problem_dir/
        bname = os.path.basename(filename)
        os.rename(filename, os.path.join(problem_dir, bname))
        continue


    aveL = sum(newL) / len(newL)
    aveR = sum(newL) / len(newR)
    distAve = (aveL + aveR) / 2.

    participant_distances.append(ParticipantName)
    participant_distances.append(distAve)

    if verbose: print("Found an average distance from screen of %s." % str(distAve))

    # We'll be using these to trigger changes.
    currentMedia = ""
    currentFixevent = -1

    # Find first non-blank one (I assume you don't start immediately with a stim
    # on the screen).
    for i in range(1, len(d)):
        if d[i][MediaName] != '' and d[i][MediaName]!='-9999':
            currentMedia = d[i][MediaName]
            currentFixevent = d[i][FixationIndex]
            line = i
            break

    if verbose:
        print("Starting with stimulus %s, fixation index %s, at line %i..."
              % (currentMedia, currentFixevent, line))
        print("Starting at <range(%i, %i)>..." % (line, len(d)))

    # Init dictionary to later store longest duration.
    l_dur = {}

    # init lists to later store all potential durations.
    leakLines = []

    # based on stimuli, init blank spots for the dictionaries.
    for each in locations:
        # start a dictionary of fixation numbers, because I'll have to
        # decide AFTER the fact which one to report.
        l_dur[each] = {'-1': [-1, -1, -1]}
        # each fixation will contain
        # [-1, -1, -1]
        # which is
        # [start line, end line, calculated duration]

    print("Done.\nFinding all possible duration locations...")
    ##### Find all potential markers for leak, duration
    # Every time you hit a new FixationIndex, store that information for the Leak list.
    for i in range(line, len(d)):
        if currentFixevent != d[i][FixationIndex]:
            # grab the line that changed.  The blank ones will contain timestamps we want.
            if hasvalidity:
                leakLines.append([i, d[i][MediaName], d[i][RecordingTimestamp],
                                  d[i][FixationIndex], d[i][GazeEventDuration],
                                  d[i][GazePointX], d[i][GazePointY], d[i][ValidityLeft],
                                  d[i][ValidityRight]])
            else:
                leakLines.append([i, d[i][MediaName], d[i][RecordingTimestamp],
                                  d[i][FixationIndex], d[i][GazeEventDuration],
                                  d[i][GazePointX], d[i][GazePointY]])
            currentFixevent = d[i][FixationIndex]  # and update fixation event.

    ##### Find all potential markers for non leak, duration
    # reset for non leak duration
    currentMedia = d[line][MediaName]
    currentFixevent = d[line][FixationIndex]
    # every time you hit a new FixationIndex or new MediaName, store
    # that information for the Leak list.

    ##### Find the max duration actual lines and times.
    ## Leak, duration
    print("Finding maximum eye gaze duration...")

    # In case the first fixation occurred before the first stimulus, we're not
    # using that at all; throw it away. You'll know because the first stim
    # fixation index is blank.

    # Before you get here, you'll need to KNOW that you got files with some
    # FixationIndex inside.  If you did not, log that and skip.
    # This is for improperly formatted or information-lacking CSVs that
    # did NOT get processed.
    if len(leakLines) == 0:
        cvs_names_skipped.append(filename)
        print("I didn't find any fixations.  Skipping file: \n%s." % filename)
        continue

    if leakLines[0][3] == '' or leakLines[0][3] == '-9999':
        print("First line in leakLines was bad; removing.")
        leakLines.pop(0)

    #if leakLines[-1][3] == '' or leakLines[-1][3] == '-9999':
    #    print("Last line in leakLines was bad; removing.")
    #    leakLines.pop(-1)


    for i in range(0, len(leakLines), 2): # Should be even number
        # If len(leakLines) is odd, don't consider the last index as the start of a fixation
        if i+1==len(leakLines):
          break

        # If you STARTED at a blank line, move on.  I don't care if they are
        # both blank because that is included in the case where the first line
        # is blank.
        if leakLines[i][1] == ''  and leakLines[i+1][1] == '':
            continue
        if leakLines[i][1]== '-9999'  and leakLines[i+1][1] == '-9999':
          continue

        # Ignore if this duration had invalid eye marks.
        if hasvalidity:
            if (leakLines[i][-1] != '0' and leakLines[i][-2] != '0'):
                print("Invalid eye markers in this line; ignoring that as a \
potential longest-duration: ")
                print(leakLines[i])
                continue

        # Calculate each potential longest duration.
        templine = []
        # line order: event line start, event line end, time.
        templine.append(leakLines[i][0])  # the line to start reading at
        templine.append(leakLines[i + 1][0])  # the line to stop reading at (don't include)
        templine.append(int(leakLines[i + 1][2]) - int(leakLines[i][2]))  # actual time this took.
        fixNumber = leakLines[i][3]

        # Compare to the existing longest duration and update if needed.
        curKey = leakLines[i][1]  # e.g. TopRight.avi
        if curKey in l_dur.keys():
            #print("Key not found! I am looking for <%s> and couldn't it in \ your list of stimuli:" % curKey)
            #print(list(l_dur.keys()))
            l_dur[leakLines[i][1]][fixNumber] = templine
        #else:  # else keep track because later I'll need to sort by fixation length AND degrees accuracy
            # if templine[-1] > l_dur[leakLines[i][1]][-1]:
            #    l_dur[leakLines[i][1]] = templine

    # At this point, the dictionaries contain stuff like:
    # 'TopLeft.avi': {'4': [6155, 6177, 73], '2': [5444, 5469, 84], '3': [6077, 6101, 80]},
    # 'TopRight.avi': {'1': [3839, 3862, 77]}

    print("Loading data for all durations...")
    # Now we need to go through the lines between e.g. 658 - 688 and
    # store the X, Y coord pairs, etc etc.
    # Eventually the l_dur[TopRight.jpg] =
    #     [start line, end line, total time, [all X, Y coordinates [][][]],
    #     [Average Coordinates], EuclideanDistance, SD, RMS]

    remKeys = []  # to store datapoints I'll need to remove.
    for eachstimulus in l_dur:
        for eachfixation in l_dur[eachstimulus]:
            l_dur[eachstimulus][eachfixation].append([])  # this empty list is about to hold all the (x,y) coordinates.
            for i in range(l_dur[eachstimulus][eachfixation][0], l_dur[eachstimulus][eachfixation][1]):
                if hasvalidity:
                    if (d[i][ValidityLeft] == '0') or (d[i][ValidityRight] == '0'):
                        if 0 < int(d[i][GazePointX]) < int(pix_width) and 0 < int(d[i][GazePointY]) < int(pix_height):
                            try:
                                l_dur[eachstimulus][eachfixation][3].append(
                                    [int(d[i][GazePointX]), int(d[i][GazePointY])])
                            except:
                                print("Throwing exception at data line %i." % i)
                                print("ValidityLeft = %i; ValidityRight = %i" % (ValidityLeft, ValidityRight))
                                print("GazePointX = %i, GazePointY = %i" % (GazePointX, GazePointY))
                                print("l_dur[eachstimulus][eachfixation] = ")
                                print(l_dur[eachstimulus][eachfixation])
                                print("eachstimilus is currently %s; eachfixation is %s.\n\n\n\n\n" % (
                                eachstimulus, eachfixation))
                                exit()
                        elif verbose:
                            print("The line contained negative values: %i, %i" % (
                            int(d[i][GazePointX]), int(d[i][GazePointY])))

                else:  # no Validity columns, but still check that it's within specified width and height.
                    if 0 < int(d[i][GazePointX]) < int(pix_width) and 0 < int(d[i][GazePointY]) < int(pix_height):
                        try:
                            l_dur[eachstimulus][eachfixation][3].append([int(d[i][GazePointX]), int(d[i][GazePointY])])
                        except:
                            print("I tried to assume this line was valid but I can't find gaze points:")
                            print(d[i])
                    elif verbose:
                        print("The line contained negative values: %i, %i" % (
                        int(d[i][GazePointX]), int(d[i][GazePointY])))

            # Now dictionary also contains all the right points, e.g.
            # 'TopRight.avi': {'1': [3839, 3862, 77, [[1442, 275], [1433, 281], [1437, 281], [1441, 287],
            #   [1445, 272], [1446, 263], [1445, 283], [1454, 277], [1430, 268]]]},

            if verbose:
                print("Finding average points for %s / fix %s..." % (eachstimulus, eachfixation))
            # Find the average (x,y) for the set of points.

            try:
                tempave = find_ave_xy(l_dur[eachstimulus][eachfixation][3])
            except:
                tempave = "N/A"
                print("Couldn't get average points for stimulus %s / fix %s, no values found." % (
                eachstimulus, eachfixation))
                if int(eachfixation) > -1:
                    print("\n\tThis fixation had such bad data (couldn't get any data from it)\
\n\tthat I'll remove it from consideration.  If you think this is in error, you can go\
\n\tback to the originating file (%s) and look at fixation #%s and verify that it's as\
\n\tuniformative as I think it is.  Data that has caused this before is that at least\
\n\tone eye was always a negative value.\n" % (filename.split('/')[-1], eachfixation))
                    remKeys.append((eachstimulus, eachfixation))

            l_dur[eachstimulus][eachfixation].append(tempave)

            # Now dictionary contains the average points, e.g.,
            # {'TopRight.avi': {'1': [3839, 3862, 77, [[1442, 275], [1433, 281], [1437, 281], [1441, 287],
            # [1445, 283], [1454, 277], [1430, 268]], [1443.0869565217392, 275.95652173913044]]},

            if verbose:
                print("Finding Euclidean distance from average points to stimulus coordinates for %s / %s..." % (
                eachstimulus, eachfixation))
            # using the average points found above, find the Euclidean distance from average to actual stimulus points.
            try:
                temppoints = find_euclid_dist(l_dur[eachstimulus][eachfixation][-1], locations[eachstimulus])
                # [-1] because the last thing found was the average points.
            except:
                temppoints = "N/A"
                print("Couldn't get Euclidean distance points for stimulus %s / %s, no values found." % (
                eachstimulus, eachfixation))
            l_dur[eachstimulus][eachfixation].append(temppoints)

            # Now dictionary includes euclidean distance, e.g. nonl_dur["Middle.jpg"] ==
            # [327, 338, 643, [[979, 533], [977, 541], ... [969, 558], [974, 558]], (974, 554), 19.79898987322333]

            if verbose:
                print("Finding SD and RMS for points for %s / %s..." % (eachstimulus, eachfixation))
            # Find the SD and RMS.
            try:
                tempsd = find_sd(l_dur[eachstimulus][eachfixation][3])  # the last thing found was the average points.
                temprms = find_rms(l_dur[eachstimulus][eachfixation][3])
            except:
                tempsd = "N/A"
                temprms = "N/A"

            l_dur[eachstimulus][eachfixation].append(tempsd)
            l_dur[eachstimulus][eachfixation].append(temprms)

    # remove anything that was such bad data I should stop considering it.
    for (es, ef) in remKeys:
        print("Removing %s / %s completely..." % (es, ef))
        del l_dur[es][ef]

        # Now each entry contains:
    # {'TopRight.avi': {'1':
    # start, end, duration, [all coordinates],         average coords,   euclid distance, SD, RMS.
    # [3839, 3862, 77, [[1442, 275], ... [1430, 268]], [1443.08, 275.9], 6.7, [7.28, 7.28], [10.65, 9.86]]},

    print("Done.  Figuring out the longest fixations per stimulus less than 6 degrees...")
    ########################################################
    # Figure out which one I actually want.  It's got to the
    # longest fixation under 6 degrees (<, not <=)

    if verbose:
        print("Durations dictionary, before removing fixations >= 6 degrees or finding longest duration:")
        for key in l_dur:
            print("l_dur[%s]: %s" % (key, str(l_dur[key])))

    removeThese = []

    for eachstim in l_dur.keys():
        print("Considering fixations for %s: %s" % (eachstim, str(l_dur[eachstim].keys())))
        for eachfix in l_dur[eachstim].keys():
            if eachfix == '-1':
                pass
            else:
                height_screen = find_degree(l_dur[eachstim][eachfix][-3], distAve, pix_height, mm_height)
                width_screen = find_degree(l_dur[eachstim][eachfix][-3], distAve, pix_width, mm_width)
                euclid_dist = (height_screen + width_screen) / 2.0
                if euclid_dist >= 6.:
                    print("Stimulus %s, fixation #%s, degrees is %f >= 6, so removing from consideration." % (
                    eachstim, eachfix, euclid_dist))
                    removeThese.append([eachstim, eachfix])

    for (s, f) in removeThese:
        del l_dur[s][f]

    # Now we're ready to find the longest within the valid fixes.
    for eachstim in l_dur.keys():
        longestFixValue = -1  # e.g., 140 ms
        longestFixIndex = '-1'  # e.g. fixation 13
        for curfix in l_dur[eachstim].keys():

            # are you a blank / nothing fixation? skip.
            if curfix == '-1':
                continue

            # Are you a longer fix?  Keep it.
            elif longestFixValue < l_dur[eachstim][curfix][2]:
                longestFixValue = l_dur[eachstim][curfix][2]
                longestFixIndex = curfix

            # Are you tied? Keep the CLOSET fixation by degree.
            elif longestFixValue == l_dur[eachstim][curfix][2]:
                # CURRENTLY KNOWN LONGEST FIXATION
                height_screen = find_degree(l_dur[eachstim][longestFixIndex][-3], distAve, pix_height, mm_height)
                width_screen = find_degree(l_dur[eachstim][longestFixIndex][-3], distAve, pix_width, mm_width)
                longestFix_euclid_dist = (height_screen + width_screen) / 2.0
                # THE FIX I JUST SAW
                height_screen = find_degree(l_dur[eachstim][curfix][-3], distAve, pix_height, mm_height)
                width_screen = find_degree(l_dur[eachstim][curfix][-3], distAve, pix_width, mm_width)
                curfix_euclid_dist = (height_screen + width_screen) / 2.0

                print(
                    "There was a tie for longest fixation.  Old index %s / time %s / degree %s; new fix %s / time %s / degree %s." % (
                    longestFixIndex, longestFixValue, longestFix_euclid_dist, curfix, l_dur[eachstim][curfix][2],
                    curfix_euclid_dist))

                # IF IT'S BETTER, KEEP IT.
                if curfix_euclid_dist > longestFix_euclid_dist:
                    print("The newer tie was closer.  Keeping.")
                    longestFixValue = l_dur[eachstim][curfix][2]
                    longestFixIndex = curfix

        l_dur[eachstim] = l_dur[eachstim][longestFixIndex]

    if verbose:
        print("Durations dictionary, before removing fixations >= 6 degrees or finding longest duration:")
        for key in l_dur:
            print("l_dur[%s]: %s" % (key, str(l_dur[key])))

    print("Done.  Printing to file...")

    ########################################################
    # Output data.
    groupdata = []

    # header = [
    #  'Stimulus',
    #  'Fix D / Min Euclid. dist.',
    #  'Fix D coordinates',
    #  'Fix D duration',
    #  'SD',
    #  'RMS']
    groupdata.append([ParticipantName])

    # start, end, duration, [all coordinates], average coords, euclid distance, SD, RMS.
    # [283, 288, 653, [[1426, 796], [1427, 799], [1419, 799], [1419, 803], [1419, 805]], (1422, 800), 20.591260281974, (3, 3), (3, 2)]
    # DURATION -
    # [555, 564, 1789, [[475, 291], [472, 289], ... [491, 300]], (485, 296), 26.476404589747453, (9, 5), (7, 5)]

    groupdata.append(header)

    # sort them because it's irritating to be out of order
    stims = []
    for stim in locations:
        stims.append(stim)
    stims = sorted(stims)

    eucliddist_ave = []
    averageSDD_x = []
    averageSDD_y = []
    averageRMSD_x = []
    averageRMSD_y = []

    for stim in stims:
        if 'N/A' in l_dur[stim]:
            groupdata.append([stim, 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A'])
        else:
            ## for min euclid distance:
            height_screen = find_degree(l_dur[stim][-3], distAve, pix_height, mm_height)
            width_screen = find_degree(l_dur[stim][-3], distAve, pix_width, mm_width)
            euclid_dist = (height_screen + width_screen) / 2.0
            eucliddist_ave.append(euclid_dist)
            ## for Fix SD, X
            height_screen = find_degree(l_dur[stim][-2][0], distAve, pix_height, mm_height)
            width_screen = find_degree(l_dur[stim][-2][0], distAve, pix_width, mm_width)
            fixsd_x = (height_screen + width_screen) / 2.0
            averageSDD_x.append(fixsd_x)
            ## for Fix SD, Y
            height_screen = find_degree(l_dur[stim][-2][1], distAve, pix_height, mm_height)
            width_screen = find_degree(l_dur[stim][-2][1], distAve, pix_width, mm_width)
            fixsd_y = (height_screen + width_screen) / 2.0
            averageSDD_y.append(fixsd_y)
            ## for Fix RMS, X
            height_screen = find_degree(l_dur[stim][-1][0], distAve, pix_height, mm_height)
            width_screen = find_degree(l_dur[stim][-1][0], distAve, pix_width, mm_width)
            fixrms_x = (height_screen + width_screen) / 2.0
            averageRMSD_x.append(fixrms_x)
            ## for Fix RMS, Y
            height_screen = find_degree(l_dur[stim][-1][1], distAve, pix_height, mm_height)
            width_screen = find_degree(l_dur[stim][-1][1], distAve, pix_width, mm_width)
            fixrms_y = (height_screen + width_screen) / 2.0
            averageRMSD_y.append(fixrms_y)

            groupdata.append([
                #  'Stimulus',
                stim,
                #  'Fix D / Min Euclid. dist.',
                "%.2f" % euclid_dist,
                #  'Fix D coordinates',
                float("%.2f" % (l_dur[stim][-4][0])), float("%.2f" % (l_dur[stim][-4][1])),
                #  'Fix D duration',
                "%.2f" % (l_dur[stim][2]),
                #  'SD',
                float("%.2f" % fixsd_x), float("%.2f" % fixsd_y),
                #  'RMS']
                float("%.2f" % fixrms_x), float("%.2f" % fixrms_y)])

    averageDistD = 0.0
    averageCoordsD = [0.0, 0.0]
    averageDurationD = 0.0
    averageSDD = [0.0, 0.0]
    averageRMSD = [0.0, 0.0]

    divby = 0  # this will increment ONLY if there were valid values.
    for stim in stims:
        if 'N/A' not in l_dur[stim]:
            divby += 1
            averageCoordsD[0] += l_dur[stim][-4][0]
            averageCoordsD[1] += l_dur[stim][-4][1]
            averageDurationD += l_dur[stim][2]

    if len(eucliddist_ave) > 0:
        averageDistD = sum(eucliddist_ave) / len(eucliddist_ave)
        averageSDD[0] = sum(averageSDD_x) / len(averageSDD_x)
        averageSDD[1] = sum(averageSDD_y) / len(averageSDD_y)
        averageRMSD[0] = sum(averageRMSD_x) / len(averageRMSD_x)
        averageRMSD[1] = sum(averageRMSD_y) / len(averageRMSD_y)

    # Before you get here, you'll need to KNOW that you got files with some
    # FixationIndex inside.  If you did not, here is where you log that and skip.
    # Improperly formatted or information-lacking CSVs that did NOT get processed.
    if divby == 0:
        cvs_names_skipped.append(filename)
        print("I found fixations, but not on stimuli. Skipping file %s." % filename)
        continue

    averageDistD = "%.2f" % averageDistD
    averageCoordsD[0] = float("%.2f" % (averageCoordsD[0] / divby))
    averageCoordsD[1] = float("%.2f" % (averageCoordsD[1] / divby))
    averageDurationD = "%.2f" % (averageDurationD / divby)
    averageSDD[0] = float("%.2f" % averageSDD[0])
    averageSDD[1] = float("%.2f" % averageSDD[1])
    averageRMSD[0] = float("%.2f" % averageRMSD[0])
    averageRMSD[1] = float("%.2f" % averageRMSD[1])

    groupdata.append(["Averages:",
                      averageDistD, averageCoordsD[0], averageCoordsD[1], averageDurationD,
                      averageSDD[0], averageSDD[1], averageRMSD[0], averageRMSD[1]])

    ## Lastly, print the tally of valid / total stimuli:
    groupdata.append(["Number valid:", "%s / %s points" % (divby, len(locations))])

    with open(dirname + '_output.csv', 'a', newline='') as fp:
        wf = csv.writer(fp, delimiter=',')
        wf.writerows(groupdata)

    print("Done with this file!")

    # Increment tally of good files.
    csv_names_processed.append(filename)

print("*********************************************************")
print("\nWrote results to file <%s>.  \nWriting summary to <%s>..."
      % (dirname + '_output.csv', dirname + '_summary.txt'))
logf = open(dirname + '_summary.txt', 'a')
logf.write("------ Script finish at time %s with results: ------" %
           (str(datetime.datetime.now())))
logf.write("\n\nNon-csv files skipped: %i" % len(nonc_names_skipped))
if len(nonc_names_skipped) > 0:
    logf.write("\nFile names:")
    for item in nonc_names_skipped:
        logf.write('\n' + item)

logf.write("\n\nCSV files processed: %i" % len(csv_names_processed))
if len(csv_names_processed) > 0:
    logf.write("\nFile names:")
    for item in csv_names_processed:
        logf.write('\n' + item)

logf.write("\n\nCSV files skipped (e.g., due to no fixation indices on stimuli, \
or no fixations at all, etc.): %i" % len(cvs_names_skipped))
if len(cvs_names_skipped) > 0:
    logf.write("\nFile names:")
    for item in cvs_names_skipped:
        logf.write('\n' + item)

logf.write('\n\n')
logf.close()

print("*********************************************************")
print("\nWriting distance-to-screen summary to <%s>..."
      % (dirname + '_distances_summary.csv'))
logf = open(dirname + '_distances_summary.csv', 'a')
aveDist = 0

logf.write("Participant Name, Ave. Distance\n")
for i in range(0, len(participant_distances), 2):
    logf.write("%s, %s\n" % (participant_distances[i], participant_distances[i + 1]))
    aveDist += participant_distances[i + 1]

aveDist /= len(participant_distances) / 2
logf.write("Ave. dist. to screen, %s" % aveDist)
logf.close()

print("Done!\n")


