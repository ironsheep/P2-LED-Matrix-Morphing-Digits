#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from datetime import datetime
from tzlocal import get_localzone

import os

from enum import Enum

import sys
import os.path
import argparse
from time import time, sleep, localtime, strftime
from collections import OrderedDict
from colorama import init as colorama_init
from colorama import Fore, Back, Style
from signal import signal, SIGPIPE, SIG_DFL

signal(SIGPIPE,SIG_DFL)

script_version = "0.0.1"
script_name = 'pymorph.py'
script_info = '{} {}'.format(script_name, script_version)
project_name = 'A Morphing Digits animation calculator'
project_url = 'https://github.com/ironsheep/P2-LED-Matrix-Morphing-Digits'

# we'll use this throughout
local_tz = get_localzone()

if False:
    # will be caught by python 2.7 to be illegal syntax
    print_line('Sorry, this script requires a python3 runtime environment.', file=sys.stderr)

# Argparse
opt_debug = False
opt_verbose = False
opt_writeOutput = False
out_fp = None

# -----------------------------------------------------------------------------
# Logging function
def print_line(text, error=False, warning=False, info=False, verbose=False, debug=False, console=True, sd_notify=False, log=False):
    timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime())
    if console:
        if log:
            if opt_writeOutput and out_fp is not None:
                out_fp.write('{}'.format(text) + '\n')
        elif error:
            print(Fore.RED + Style.BRIGHT + '[{}] '.format(timestamp) + Style.RESET_ALL + '{}'.format(text) + Style.RESET_ALL, file=sys.stderr)
        elif warning:
            print(Fore.YELLOW + Style.BRIGHT + '[{}] '.format(timestamp) + '(WARNING) ' + Style.RESET_ALL + Fore.YELLOW  + '{}'.format(text) + Style.RESET_ALL)
        elif info or verbose:
            if info:
                print(Fore.GREEN + Style.BRIGHT  + '[{}] '.format(timestamp) +  '- ' + '{}'.format(text) + Style.RESET_ALL)
            elif opt_verbose:
                print(Fore.YELLOW + '[{}] '.format(timestamp) + Style.RESET_ALL + '(VERBOSE) {}'.format(text) + Style.RESET_ALL)
        elif debug:
            if opt_debug:
                print(Fore.CYAN + '[{}] '.format(timestamp) + '(DBG): ' + '{}'.format(text) + Style.RESET_ALL)
        else:
            print(Fore.GREEN + '[{}] '.format(timestamp) + Style.RESET_ALL + '{}'.format(text) + Style.RESET_ALL)

    timestamp_sd = strftime('%b %d %H:%M:%S', localtime())
    if sd_notify:
        sd_notifier.notify('STATUS={} - {}.'.format(timestamp_sd, unidecode(text)))

# -----------------------------------------------------------------------------
# Parsing command-line options
parser = argparse.ArgumentParser(description=script_info, epilog='For further details see: ' + project_url)
parser.add_argument("-v", "--verbose", help="increase output (v)erbosity", action="store_true")
parser.add_argument("-d", "--debug", help="show (d)ebug output", action="store_true")
parser.add_argument("-o", '--out_filename', help='write actions to output file', default='')
parse_args = parser.parse_args()

opt_debug = parse_args.debug
opt_verbose = parse_args.verbose
out_filename = parse_args.out_filename
opt_writeOutput = len(out_filename) > 0

print_line(script_info, info=True)
if opt_verbose:
    print_line('Verbose enabled', info=True)
if opt_debug:
    print_line('Debug enabled', debug=True)
if opt_writeOutput:
    print_line('Writing output to: {}'.format(out_filename), debug=True)

if opt_writeOutput:
    if os.path.exists(out_filename):
        print_line('Out File {} already exists, Aborting!'.format(out_filename), error=True)
        os._exit(1)
    else:
        print_line("Output started", debug=True)
        out_fp = open(out_filename, "w")

# -----------------------------------------------------------------------------
#  Misc support routines
# -----------------------------------------------------------------------------
# segment letter names:
#
#    --- a ---
#   |         |
#   f         b
#   |         |
#    --- g ---
#   |         |
#   e         c
#   |         |
#    --- d ---
#
#
# all segments by name
segmentNames = ["a", "b", "c", "d", "e", "f", "g"]

# segments adjacent to segements w/direction to adjacent
adjacent0 = ("a", "b", "right")
adjacent1 = ("a", "f", "left")
adjacent2 = ("b", "c", "bottom")
adjacent3 = ("b", "g", "bottom")
adjacent4 = ("c", "g", "top")
adjacent5 = ("c", "d", "bottom")
adjacent6 = ("d", "e", "left")
adjacent7 = ("e", "g", "top")
adjacent8 = ("f", "g", "bottom")
adjacent9 = ("f", "e", "bottom")

# list of all segment adjancencies
adjacentSegments = [adjacent0, adjacent1, adjacent2, adjacent3, adjacent4, adjacent5, adjacent6, adjacent7, adjacent8, adjacent9]

# special segments that move as a column
slidingSegments = ("e", "f")

# segments related to the special segments
source0 = ("e", "c")
source1 = ("f", "b")

# list of all special segments and their related segments
sourceSegments = [source0, source1]

# segments lit for each digit
digit0 = ("a", "b", "c", "d", "e", "f")
digit1 = (     "b", "c")
digit2 = ("a", "b",      "d", "e",      "g")
digit3 = ("a", "b", "c", "d",           "g")
digit4 = (     "b", "c",           "f", "g")
digit5 = ("a",      "c", "d",      "f", "g")
digit6 = ("a",      "c", "d", "e", "f", "g")
digit7 = ("a", "b", "c")
digit8 = ("a", "b", "c", "d", "e", "f", "g")
digit9 = ("a", "b", "c", "d",      "f", "g")

# list of all digits (indexable)
digitTuples = [digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9]

# -----------------------------------------------------------------------------
# return list of names of segments adjacent to given named segment
#
def adjacentSegementsFor(segmentName):
    adjacents = []
    for adjacentTuple in adjacentSegments:
        if segmentName in adjacentTuple:
            if segmentName == adjacentTuple[0]:
                adjacents.append(adjacentTuple[1])
            else:
                adjacents.append(adjacentTuple[0])
    return adjacents

transitionCount = 0
warningCount = 0
missingNames = []

# -----------------------------------------------------------------------------
# write an action taken, also filter and write to output data file
#
def log_line(message):
    print_line(message)
    line_left, line_right = message.split(" -> ")
    #print_line("-   seg[{}] turning OFF while [{}] is staying ON. -> Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
    #print_line("#   seg[{}] turning OFF while [{}] is staying ON.".format(segmentName, adjacentName), log=True)
    #print_line("Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName), log=True)
    print_line(message)
    if line_left is not None and len(line_left) > 0:
        print_line(line_left.replace("-   ", "#   "), log=True)
    if line_right is not None and len(line_right) > 0:
        print_line(line_right.replace("!", ""), log=True)

# -----------------------------------------------------------------------------
# calculate the segment changes between two digits
#
def calcSegDiffs(ltDigit, rtDigit):
    global transitionCount
    global warningCount
    turningOn = []
    turningOff = []
    stayingOn = []
    stayingOff = []
    transitionCount += 1
    print_line("#{}: checking lt={}, rt={}".format(transitionCount, ltDigit, rtDigit), info=True)
    print_line("\n\n#  #{}: checking lt={}, rt={}".format(transitionCount, ltDigit, rtDigit), log=True)
    ltTuple = digitTuples[ltDigit]
    rtTuple = digitTuples[rtDigit]
    # classify changes and NOT changes
    for segName in segmentNames:
        if segName in ltTuple or segName in rtTuple:
            # if segment is ON, going ON or going OFF
            print_line("* Processing seg=[{}]".format(segName), debug=True)
            if segName in ltTuple and segName in rtTuple:
                # have segment in both digits (Staying ON)
                stayingOn.append(segName)
            elif segName in ltTuple:
                # have segment turning OFF
                print_line("* seg=[{}] turning OFF".format(segName), verbose=True)
                turningOff.append(segName)
            else: # segName in rtTuple:
                # have segment turning ON
                print_line("* seg=[{}] turning ON".format(segName), verbose=True)
                turningOn.append(segName)
        else:
            # else segment is staying OFF
            stayingOff.append(segName)
            #print_line("- Lt=[{}], Rt=[{}] has NO seg=[{}]".format(ltTuple, rtTuple, segName), debug=True)

    # now identify transitions needed to cause the changes
    nbrTransitions = len(turningOff) + len(turningOn)
    countSuffix = "" if (nbrTransitions == 1) else "s"
    print_line("  {} segment{} changing, #ON={}, #OFF={}".format(nbrTransitions, countSuffix, len(turningOn), len(turningOff)), info=True)
    print_line("#  {} segment{} changing, #ON={}, #OFF={}".format(nbrTransitions, countSuffix, len(turningOn), len(turningOff)), log=True)
    bHaveAdjacentSegmentsChanging = True if len(turningOff) == 0 or len(turningOn) == 0 else False

    # for each segment that is changing do:
    for segmentName in turningOff + turningOn:
        bSegmentHandled = False
        adjacents = adjacentSegementsFor(segmentName)
        if len(adjacents) > 0:
            print_line("- adjacent segments for [{}] are [{}]".format(segmentName, adjacents), verbose=True)
            for adjacentName in adjacents:
                if bSegmentHandled == False and segmentName in turningOff and adjacentName in stayingOn:
                    # turning OFF with adjacent that is ALREADY ON, snake OFF into ON
                    log_line("-   seg[{}] turning OFF while [{}] is staying ON. -> Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOff and adjacentName in turningOn:
                    # turning OFF with adjacent that is going ON, snake OFF into ON
                    log_line("-   seg[{}] turning OFF while [{}] is turning ON. -> Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOn and adjacentName in stayingOff:
                    # turning ON with adjacent that is ALREADY OFF, snake ON into OFF
                    log_line("-   seg[{}] turning ON while [{}] is staying OFF. -> Segment [{}] snakes ON towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOn and adjacentName in turningOff:
                    # turning ON with adjacent that is going OFF, snake ON into OFF
                    log_line("-   seg[{}] turning ON while [{}] is turning OFF. -> Segment [{}] snakes ON towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOn and adjacentName in stayingOn:
                    # turning ON with adjacent that is going OFF, snake ON into OFF
                    log_line("-   seg[{}] turning ON while [{}] is staying ON. -> Segment [{}] snakes ON away from [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    bSegmentHandled = True
        if not bSegmentHandled and segmentName in slidingSegments:
            sourceTuple = source0 if segmentName in source0 else source1
            sourceName = sourceTuple[1]
            if bSegmentHandled == False and segmentName in turningOn and sourceName in stayingOn:
                # if our sliding segment is turning ON slide from source which is staying ON
                log_line("-   seg[{}] turning ON while [{}] is staying ON. -> VERT Segment [{}] slides LEFT from [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                bSegmentHandled = True
            elif bSegmentHandled == False and segmentName in turningOff and sourceName in stayingOn:
                # if our sliding segment is turning OFF slide to source which is staying ON
                log_line("-   seg[{}] turning OFF while [{}] is staying ON. -> VERT Segment [{}] slides RIGHT to [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                bSegmentHandled = True
            elif bSegmentHandled == False and segmentName in turningOff and sourceName in turningOn:
                # if our sliding segment is turning OFF slide to source which is staying ON
                log_line("-   seg[{}] turning OFF while [{}] is turning ON. -> VERT Segment [{}] slides RIGHT to [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                bSegmentHandled = True
            elif bSegmentHandled == False and segmentName in turningOn and sourceName in turningOff:
                # if our sliding segment is turning ON slide away from source which is turning OFF
                log_line("-   seg[{}] turning ON while [{}] is turning OFF. -> VERT Segment [{}] slides LEFT from [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                bSegmentHandled = True
        if not bSegmentHandled:
            print_line("- seg[{}] MISSING action".format(segmentName), warning=True)
            warningCount += 1
            if not segmentName in missingNames:
                missingNames.append(segmentName)

# -----------------------------------------------------------------------------
#  main application
# -----------------------------------------------------------------------------

print_line("- plotting segment transitions", info=True)

for ltDigit in range(10):
    for rtDigit in range(1,10):
        if ltDigit != rtDigit:
            calcSegDiffs(ltDigit, rtDigit)

countSuffix = "" if (warningCount == 1) else "s"
print_line("* {} segment{} not yet handled!".format(warningCount, countSuffix), info=True)
if len(missingNames) > 0:
    print_line("** named {}".format(missingNames), info=True)

if opt_writeOutput:
    print_line('File {} - closed'.format(out_filename), verbose=True)
    out_fp.close()
