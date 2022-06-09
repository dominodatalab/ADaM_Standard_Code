#!/bin/bash 
###############################################################################
#  ____                  _
# |  _ \  ___  _ __ ___ (_)_ __   ___
# | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
# | |_| | (_) | | | | | | | | | | (_) |
# |____/ \___/|_| |_| |_|_|_| |_|\___/
# ____________________________________________________________________________
# Sponsor              : Domino
# Compound             : Xanomeline
# Study                : H2QMCLZZT
# Analysis             : PILOT01
# Program              : runall.sh
# ____________________________________________________________________________
# DESCRIPTION 
#
# Batch run all the ADAM and TFL programs
#                                                                   
# Input files: 
#   - source files in:
#   - prod/adam/code
#   - qc/adam/code
#   - prod/tfl/code
#   - qc/tfl/code
#
# Output files:
#   - outputs and log files written to
#   - /mnt/artifacts
#
# Assumptions: 
#   - Running on Domino platform
#   - Using SAS Docker image that has R installed
# ____________________________________________________________________________
# PROGRAM HISTORY                                                         
# ----------------------------------------------------------------------------
#  20220609  | stuart.malcolm        | Created         
##############################################################################

# first off.. lets do some debug/exploration

#cat /var/lib/domino/launch/command.sh
ls -R /var/lib/domino/
ls -R  /opt/sas/spre

# lets see if run_sas is on the path
run_sas.sh qc/adam/code/ADSL.sas