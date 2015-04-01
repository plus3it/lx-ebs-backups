#!/bin/sh
#
# This script is designed to perform consistent backups of a set 
# of EBSes within a specified consistency-group.
#
#
# Dependencies:
# - Generic: See the top-level README_dependencies.md for script dependencies
# - Specific:
#   * All EBSes to be backed up as a consistency-group must be tagged:
#     * Tag-name:  "Consistency Group"
#     * Tag-value: (user-selectable)
#
# License:
# - This script released under the Apache 2.0 OSS License
#
######################################################################

# Starter Variables
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/AWScli/bin
WHEREAMI=`readlink -f ${0}`
SCRIPTDIR=`dirname ${WHEREAMI}`

# Put the bulk of our variables into an external file so they
# can be easily re-used across scripts
source ${SCRIPTDIR}/commonVars.env

# SCRIPT Variables
CONGRP=${1:-UNDEF}
BKNAME="$(hostname -s)_${THISINSTID}-bkup-${DATESTMP}"

