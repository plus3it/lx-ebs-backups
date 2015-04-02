#!/bin/sh
#
# This script is designed to perform consistent backups of
# - Selected EBS volumes (referenced by volume-id)
# - Mounted filesystems  (referenced by fully-qualified directory-path)
# - LVM volumes (referenced by VGNAME/LVNAME path-specification)
#
#
# Dependencies:
# - Generic: See the top-level README_dependencies.md for script dependencies
#
# License:
# - This script released under the Apache 2.0 OSS License
#
######################################################################

######################################
##                                  ##
## Section for variable-declaration ##
##                                  ##
######################################

#####################
# Starter Variables
#####################
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/AWScli/bin
WHEREAMI=`readlink -f ${0}`
SCRIPTDIR=`dirname ${WHEREAMI}`
PROGNAME=`basename ${WHEREAMI}`


#########################################
# Put the bulk of our variables into an
# external file so they can be easily
# re-used across scripts
#########################################
source ${SCRIPTDIR}/commonVars.env


####################
# SCRIPT Variables
####################
BKNAME="$(hostname -s)_${THISINSTID}-bkup-${DATESTMP}"



######################################
##                                  ##
## Section for function-declaration ##
##                                  ##
######################################

#########################################
# Output log-data to multiple locations
#########################################
function MultiLog() {
   echo "${1}"
   logger -p local0.info -t [Flagger] "${1}"
   # DEFINE ADDITIONAL OUTPUTS, HERE
}

############################################
# Create list of filesystems to (un)freeze
############################################
function FsSpec() {
   local FSTYP=$(stat -c %F ${1} 2> /dev/null)
   local IDX=${#FSLIST[@]}

   case ${FSTYP} in
      "directory")
         FSLIST[${IDX}]=${1}
         ;;
      "")
         MultiLog "${1} does not exist. Aborting..." >&2
         exit 1
         ;;
      *)
         MultiLog "${1} is not a directory. Aborting..." >&2
         exit 1
         ;;
   esac
}

#######################################
# Toggle set appropriate freeze-state
# on target filesystems
#######################################
function FSfreezeToggle() {
   MultiLog "OPTION '${1}' NOT YET IMPLEMENTED"
}



######################################
##                                  ##
## Section for defining main        ##
##    program function and flow     ##
##                                  ##
######################################

##################
# Option parsing
##################
OPTIONBUFR=`getopt -o v:f: --long vgname:fsname: -n ${PROGNAME} -- "$@"`
# Note the quotes around '$OPTIONBUFR': they are essential!
eval set -- "${OPTIONBUFR}"

# Parse our flagged args
while [ true ]
do
   case "$1" in
      -v|--vgname)
         # Mandatory argument. Operating in quoted mode: an
	 # empty parameter will be generated if its optional
	 # argument is not found
	 case "$2" in
	    "")
	       MultiLog "Error: option required but not specified"
	       shift 2
	       exit 1
	       ;;
	    *)
               MultiLog "VG FUNCTION NOT YET IMPLEMENTED: EXITING..." >&2
	       shift 2;
               exit 1
	       ;;
	 esac
	 ;;
      -f|--fsname)
         # Mandatory argument. Operating in quoted mode: an
	 # empty parameter will be generated if its optional
	 # argument is not found
	 case "$2" in
	    "")
	       MultiLog "Error: option required but not specified"
	       shift 2
	       exit 1
	       ;;
	    *) 
               FsSpec ${2}
               shift 2;
	       ;;
	 esac
	 ;;
      --)
         shift
         break
         ;;
      *)
         MultiLog "Internal error!"
         exit 1
         ;;
   esac
done

CONGRP=${1:-UNDEF}

# DIAGNOSTIC: REMOVE BEFORE PUSHING UP
MultiLog "My options: (flags) ${FSLIST[@]} (unflagged) ${CONGRP}"

if [ "${CONGRP}" = "UNDEF" ]
then
   MultiLog "No consistency-group specified. Aborting"
   exit 1
fi

# Generate list of related EBS Volume-IDs
VOLIDS=`aws ec2 describe-volumes --filters \
   "Name=attachment.instance-id,Values=${THISINSTID}" --filters \
   "Name=tag:Consistency Group,Values=${CONGRP}"  --query \
   "Volumes[].Attachments[].VolumeId" --output text`

if [ "${VOLIDS}" = "" ]
then
   MultiLog "No volumes found in the requested consistency-group [${CONGRP}]"
fi

# Freeze any enumerated filesystems
FSfreezeToggle freeze

# Snapshot volumes
for EBS in ${VOLIDS}
do
   MultiLog "Snapping EBS volume: ${EBS}"
   # Spawn off backgrounded subshells to reduce start-deltas across snap-set
   ( \
      SNAPIT=$(aws ec2 create-snapshot --output=text --description ${BKNAME} \
        --volume-id ${EBS} --query SnapshotId) ; \
      aws ec2 create-tags --resource ${SNAPIT} --tags Key="Created By",Value="Automated Backup" ; \
      aws ec2 create-tags --resource ${SNAPIT} --tags Key="Name",Value="AutoBack (${THISINSTID}) $(date '+%Y-%m-%d')" ; \
      aws ec2 create-tags --resource ${SNAPIT} --tags Key="Snapshot Group",Value="${DATESTMP} (${THISINSTID})"
   ) &
done

# Unfreeze any enumerated filesystems
FSfreezeToggle unfreeze
