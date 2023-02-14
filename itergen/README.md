# Quick Start

To run the iterative generation script, simply call python iter.py from the primate home directory.  The primate home directory contains both the primate-arch-gen and primate-uarch folders.

The script will apply patches to the primate template and call modified versions of the build scripts to enable iterative generation. 

The script will execute with default options when no options are passed. In order to get more fine tuned results the script offers several options detailed in usage. 

# Useage  


**'-i' or '--iterations'**

Controls the maximum number of iterations that the script will perform while trying to optimize the values seen by the performance counters


**'-p' or '--per_fu_type'**

Determines whether or not the script will configure the primate template to record performance information per functional unit. Defaults to using a performance counter per functional unit.


**'-s' or '--score_mode'**

Determines what scoring is used to find the 'best' result in design space. One of avg, rms, max, min. This scoring is applied to the performance data inputted after it is converted to percent utilization. Average and rms simply perform their respective average to the array of performance counter information. Max/Min will try to improve the maximum/minimum utilization seen by any FU respectively


**'-d' or '--design_domain'**

Determines, as a percent, how far away from initial settings the iterative gen is allowed to explore. Lower and upper bounds given as percent of original; for example 0.5 2.0 would allow iterative gen to modify values (Number of threads, ALUs, BFUs) to be between 1/2 and 2 times their original value.


**'-v' or '--verbosity'**

Verbosity on a scale of 0 to 4. Levels correspond to: 0-Critical, 1-Error, 2-Warnings, 3-Info, 4-Debug


**'-l' or '--logfile'**

Specifies an output log file, verbosity rules apply to generated output