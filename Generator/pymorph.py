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

script_version = "0.1.0"
script_name = 'pymorph.py'
script_info = '{} v{}'.format(script_name, script_version)
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
def print_line(text, error=False, warning=False, info=False, verbose=False, debug=False, console=True, sd_notify=False, code=False):
    timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime())
    if console:
        if code:
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
segmentNameSet = ["a", "b", "c", "d", "e", "f", "g"]

# segments adjacent to segments
adjacent0 = ("a", "b")
adjacent1 = ("a", "f")
adjacent2 = ("b", "c")
adjacent3 = ("b", "g")
adjacent4 = ("c", "g")
adjacent5 = ("c", "d")
adjacent6 = ("d", "e")
adjacent7 = ("e", "g")
adjacent8 = ("f", "g")
adjacent9 = ("f", "e")

# list of all segment adjancencies
adjacentSegmentSet = [adjacent0, adjacent1, adjacent2, adjacent3, adjacent4, adjacent5, adjacent6, adjacent7, adjacent8, adjacent9]

def adjacentSegementsFor(segmentName):
    # return list of names of segments adjacent to given named segment
    adjacents = []
    for adjacentTuple in adjacentSegmentSet:
        if segmentName in adjacentTuple:
            if segmentName == adjacentTuple[0]:
                adjacents.append(adjacentTuple[1])
            else:
                adjacents.append(adjacentTuple[0])
    return adjacents

# segments adjacent to segements w/direction to adjacent
adjacentDict = {
    "a->b": "right",
    "b->a": "up",
    "a->f": "left",
    "f->a": "up",
    "b->c": "down",
    "c->b": "up",
    "b->g": "down",
    "g->b": "right",
    "c->g": "up",
    "g->c": "right",
    "c->d": "down",
    "d->c": "right",
    "d->e": "left",
    "e->d": "down",
    "e->g": "up",
    "g->e": "right",
    "f->g": "down",
    "g->f": "left",
    "f->e": "down",
    "e->f": "up",
}

def relativeDirection(fmSegmentName, toSegmentName):
    # return direction of fmSegment to toSegment
    desiredDirection = None
    directionKey = "{}->{}".format(fmSegmentName, toSegmentName)
    if directionKey in adjacentDict:
        desiredDirection = adjacentDict[directionKey]
    return desiredDirection

directions0 = ("down","up")
directions1 = ("left","right")

directionSet = [directions0, directions1]

def oppositeDirection(direction):
    desiredDirection = None
    for directionTuple in directionSet:
        if direction in directionTuple:
            desiredDirection = directionTuple[1] if directionTuple[0] == direction else directionTuple[0]
            break
    return desiredDirection

directions0 = ("up", "CMD_BOTTOM_UP")
directions1 = ("down", "CMD_TOP_DOWN")
directions2 = ("right", "CMD_LT_TO_RT")
directions3 = ("left", "CMD_RT_TO_LT")

snakeEnumSet = [directions0, directions1, directions2, directions3]

directions4 = ("right", "CMD_COL_TO_RT")
directions5 = ("left", "CMD_COL_TO_LT")

slideEnumSet = [directions4, directions5]

def actionEnumFor(heading, direction):
    print_line("* actionEnumFor({}, {})".format(heading, direction))
    actionEnum = None
    if heading == "slides":
        # have column move (dir=L/R)
        for slideTuple in slideEnumSet:
            if direction in slideTuple:
                print_line("  -- FOUND slideTuple=[{}]".format(slideTuple))
                actionEnum = slideTuple[1] if slideTuple[0] == direction else slideTuple[0]
                break
            else:
                print_line("  -- NOT FOUND slideTuple=[{}]".format(slideTuple))
    else:
        # have snake move (dir=L/R,U/D)
        actionDirection = direction
        if heading == "away":
            actionDirection = oppositeDirection(direction)
        for snakeTuple in snakeEnumSet:
            if actionDirection in snakeTuple:
                print_line("  -- FOUND actionDirection=[{}], snakeTuple=[{}]".format(actionDirection, snakeTuple))
                actionEnum = snakeTuple[1] if snakeTuple[0] == actionDirection else snakeTuple[0]
                break
            else:
                print_line("  -- NOT FOUND actionDirection=[{}], snakeTuple=[{}]".format(actionDirection, snakeTuple))

    return actionEnum


# special segments that move as a column
slidingSegments = ("e", "f")

# segments related to the special segments
source0 = ("e", "c")
source1 = ("f", "b")

# list of all special segments and their related segments
sourceSegmentSet = [source0, source1]

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
digitTupleSet = [digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9]

tablePrefix = "fm"
accessPrefix = "segments."
linePrefix = "\tbyte\t"

# list of segment name with segment enum name
segment0enum = ("a", "SEG_TOP_A")
segment1enum = ("b", "SEG_RIGHT_B")
segment2enum = ("c", "SEG_RIGHT_C")
segment3enum = ("d", "SEG_BOTTOM_D")
segment4enum = ("e", "SEG_LEFT_E")
segment5enum = ("f", "SEG_LEFT_F")
segment6enum = ("g", "SEG_MIDDLE_G")

# list of all segment ENUM names
segmentEnumSet = [segment0enum, segment1enum, segment2enum, segment3enum, segment4enum, segment5enum, segment6enum]

def segmentEnumforName(segmentName):
    # return enum name for givem segment name else None
    desiredEnum = None
    for segmentTuple in segmentEnumSet:
        if segmentName in segmentTuple:
            #print_line("- FOUND segmentTuple=[{}]".format(segmentTuple))
            desiredEnum = segmentTuple[1] if segmentTuple[0] == segmentName else segmentTuple[0]
            break
        #else:
            #print_line("- NOT FOUND segmentTuple=[{}]".format(segmentTuple))
    return desiredEnum


transitionCount = 0
warningCount = 0
missingNameSet = []

# -----------------------------------------------------------------------------
# write an action taken, also filter and write to output data file
#
def log_line(message):
    print_line(message)
    line_left, line_right = message.split(" -> ")
    #print_line("-   seg[{}] turning OFF while [{}] is staying ON. -> Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
    #print_line("#   seg[{}] turning OFF while [{}] is staying ON.".format(segmentName, adjacentName), code=True)
    #print_line("Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName), code=True)
    print_line(message)
    if line_left is not None and len(line_left) > 0:
        print_line("\t{}".format(line_left.replace("-   ", "' ")), code=True)
    if line_right is not None and len(line_right) > 0:
        print_line("\t' {}".format(line_right.replace("!", "")), code=True)

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
    print_line("\n{}{}_{}\n\t' transition #{}: digit {} -> {}".format(tablePrefix, ltDigit, rtDigit, transitionCount, ltDigit, rtDigit), code=True)
    ltTuple = digitTupleSet[ltDigit]
    rtTuple = digitTupleSet[rtDigit]
    # classify changes and NOT changes
    for segName in segmentNameSet:
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
    print_line("\t' {} segment{} changing, #ON={}, #OFF={}".format(nbrTransitions, countSuffix, len(turningOn), len(turningOff)), code=True)
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
                    direction = relativeDirection(segmentName, adjacentName)
                    print_line("{}{}{} + {}CMD_TURN_OFF + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("towards", direction)), code=True)
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOff and adjacentName in turningOn:
                    # turning OFF with adjacent that is going ON, snake OFF into ON
                    log_line("-   seg[{}] turning OFF while [{}] is turning ON. -> Segment [{}] snakes OFF towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    direction = relativeDirection(segmentName, adjacentName)
                    print_line("{}{}{} + {}CMD_TURN_OFF + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("towards", direction)), code=True)
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOn and adjacentName in stayingOff:
                    # turning ON with adjacent that is ALREADY OFF, snake ON into OFF
                    log_line("-   seg[{}] turning ON while [{}] is staying OFF. -> Segment [{}] snakes ON towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    direction = relativeDirection(segmentName, adjacentName)
                    print_line("{}{}{} + {}CMD_TURN_ON + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("towards", direction)), code=True)
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOn and adjacentName in turningOff:
                    # turning ON with adjacent that is going OFF, snake ON into OFF
                    log_line("-   seg[{}] turning ON while [{}] is turning OFF. -> Segment [{}] snakes ON towards [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    direction = relativeDirection(segmentName, adjacentName)
                    print_line("{}{}{} + {}CMD_TURN_ON + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("towards", direction)), code=True)
                    bSegmentHandled = True
                elif bSegmentHandled == False and segmentName in turningOn and adjacentName in stayingOn:
                    # turning ON with adjacent that is going OFF, snake ON into OFF
                    log_line("-   seg[{}] turning ON while [{}] is staying ON. -> Segment [{}] snakes ON away from [{}]!".format(segmentName, adjacentName, segmentName, adjacentName))
                    direction = relativeDirection(segmentName, adjacentName)
                    print_line("{}{}{} + {}CMD_TURN_ON + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("away", direction)), code=True)
                    bSegmentHandled = True
        if not bSegmentHandled and segmentName in slidingSegments:
            sourceTuple = source0 if segmentName in source0 else source1
            sourceName = sourceTuple[1]
            if bSegmentHandled == False and segmentName in turningOn and sourceName in stayingOn:
                # if our sliding segment is turning ON slide from source which is staying ON
                log_line("-   seg[{}] turning ON while [{}] is staying ON. -> VERT Segment [{}] slides LEFT from [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                print_line("{}{}{} + {}CMD_TURN_ON + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("slides", "left")), code=True)
                bSegmentHandled = True
            elif bSegmentHandled == False and segmentName in turningOff and sourceName in stayingOn:
                # if our sliding segment is turning OFF slide to source which is staying ON
                log_line("-   seg[{}] turning OFF while [{}] is staying ON. -> VERT Segment [{}] slides RIGHT to [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                print_line("{}{}{} + {}CMD_TURN_OFF + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("slides", "right")), code=True)
                bSegmentHandled = True
            elif bSegmentHandled == False and segmentName in turningOff and sourceName in turningOn:
                # if our sliding segment is turning OFF slide to source which is staying ON
                log_line("-   seg[{}] turning OFF while [{}] is turning ON. -> VERT Segment [{}] slides RIGHT to [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                print_line("{}{}{} + {}CMD_TURN_OFF + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("slides", "right")), code=True)
                bSegmentHandled = True
            elif bSegmentHandled == False and segmentName in turningOn and sourceName in turningOff:
                # if our sliding segment is turning ON slide away from source which is turning OFF
                log_line("-   seg[{}] turning ON while [{}] is turning OFF. -> VERT Segment [{}] slides LEFT from [{}]!".format(segmentName, sourceName, segmentName, sourceName))
                print_line("{}{}{} + {}CMD_TURN_ON + {}{}".format(linePrefix, accessPrefix, segmentEnumforName(segmentName), accessPrefix, accessPrefix, actionEnumFor("slides", "left")), code=True)
                bSegmentHandled = True
        if not bSegmentHandled:
            print_line("- seg[{}] MISSING action".format(segmentName), warning=True)
            warningCount += 1
            if not segmentName in missingNameSet:
                missingNameSet.append(segmentName)
    print_line("{}0\t' terminate entry".format(linePrefix), code=True)

# -----------------------------------------------------------------------------
#  main application
# -----------------------------------------------------------------------------

print_line("- plotting segment transitions", info=True)

for ltDigit in range(10):
    for rtDigit in range(10):
        if ltDigit != rtDigit:
            calcSegDiffs(ltDigit, rtDigit)

countSuffix = "" if (warningCount == 1) else "s"
print_line("* {} segment{} not yet handled!".format(warningCount, countSuffix), info=True)
if len(missingNameSet) > 0:
    print_line("** named {}".format(missingNameSet), info=True)

if opt_writeOutput:
    print_line('File {} - closed'.format(out_filename), verbose=True)
    out_fp.close()
