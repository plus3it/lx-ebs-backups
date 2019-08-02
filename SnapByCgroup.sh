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
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/AWScli/bin
PROGNAME="$( basename "${BASH_SOURCE[0]}" )"
PROGDIR="$( dirname "${BASH_SOURCE[0]}" )"


#########################################
# Put the bulk of our variables into
# sourcable files so they can be easily
# re-used across scripts
#########################################
source ${PROGDIR}/commonVars.env
source ${PROGDIR}/setcred.sh


####################
# SCRIPT Variables
####################
BKNAME="$(hostname -s)_${THISINSTID}-bkup-${DATESTMP}"
FIFO=/tmp/EBSfifo


######################################
##                                  ##
## Section for function-declaration ##
##                                  ##
######################################


#################################################
# Check script invocation-method; set tag-value
#################################################
function GetInvocation {
   tty -s
   if [ $? -eq 0 ]
   then
      CREATEMETHOD="Manually-Initiated Backup"
   elif [ $? -eq 1 ]
   then
      CREATEMETHOD="Automated Backup"
   fi
}

############################################
# Create list of filesystems to (un)freeze
############################################
function FsSpec {
   # Scoped declaration
   local FSTYP
   local IDX

   FSTYP=$(stat -c %F "${1}" 2> /dev/null)
   IDX=${#FSLIST[@]}

   case ${FSTYP} in
      "directory")
         FSLIST[${IDX}]=${1}
         ;;
      "")
         logIt "${1} does not exist. Aborting... " 1
         ;;
      *)
         logIt "${1} is not a directory. Aborting... " 1
         ;;
   esac
}

#######################################
# Toggle set appropriate freeze-state
# on target filesystems
#######################################
function FSfreezeToggle {
   # Scoped declaration
   local IDX
   local ACTION=${1}

   ACTION=${1}

   case ${ACTION} in
      "freeze")
	 FRZFLAG="-f"
         ;;
      "unfreeze")
	 FRZFLAG="-u"
         ;;
      "")	# THIS SHOULD NEVER MATCH
	 logIt "No freeze method specified" 1
         ;;
      *)	# THIS SHOULD NEVER MATCH
	 logIt "Invalid freeze method specified" 1
         ;;
   esac

   if [ ${#FSLIST[@]} -gt 0 ]
   then
      IDX=0
      while [ ${IDX} -lt ${#FSLIST[@]} ]
      do
         logIt "Attempting to ${ACTION} '${FSLIST[${IDX}]}'" 0

	 fsfreeze ${FRZFLAG} "${FSLIST[${IDX}]}" && \
            logIt "${ACTION} succeeded" 0 || \
	      logIt "${ACTION} on ${FSLIST[${IDX}]} exited abnormally" 1

	 IDX=$((${IDX} + 1))
      done
   else
      logIt "No filesystems selected for ${ACTION}" 0
   fi
}


##################
# Option parsing
##################
OPTIONBUFR="$( getopt -o v:f: --long vgname:fsname: -n ${PROGNAME} -- "$@" )"
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
	       shift 2
	       logIt "Error: option required but not specified" 1
	       ;;
	    *)
	       shift 2;
               logIt "VG FUNCTION NOT YET IMPLEMENTED: EXITING..." 1
	       ;;
	 esac
	 ;;
      -f|--fsname)
         # Mandatory argument. Operating in quoted mode: an
	 # empty parameter will be generated if its optional
	 # argument is not found
	 case "$2" in
	    "")
	       shift 2
	       logIt "Error: option required but not specified" 1
	       ;;
	    *) 
               FsSpec "${2}"
               shift 2;
	       ;;
	 esac
	 ;;
      --)
         shift
         break
         ;;
      *)
         logIt "Internal error!" 1
         ;;
   esac
done

# Only after flag-parsing is done, can we set the 
# var to the unflagged consistency-group variable
CONGRP=${1:-UNDEF}

# Make sure the consistency-group is specified
if [ "${CONGRP}" = "UNDEF" ]
then
   logIt "No consistency-group specified. Aborting" 1
fi

# Generate list of all EBSes attached to this instance
ALLVOLIDS="$(
      aws ec2 describe-volumes \
         --filters "Name=attachment.instance-id,Values=${THISINSTID}" \
         --query "Volumes[].Attachments[].VolumeId" --output text
   )"

COUNT=0
for VOLID in ${ALLVOLIDS}
do
   VOLIDS[${COUNT}]=$(aws ec2 describe-volumes --volume-id ${VOLID} --filters "Name=tag:Consistency Group,Values=${CONGRP}" --query "Volumes[].Attachments[].VolumeId" --output text)
   COUNT=$((${COUNT} + 1))
done


if [[ "${VOLIDS[@]}" = "" ]]
then
   logIt "No volumes found in the requested consistency-group [${CONGRP}]" 0
fi

# Gonna go old school (who the heck uses named pipes in shell scripts???)
if [[ ! -p ${FIFO} ]]
then
   mkfifo ${FIFO}
fi

# Freeze any enumerated filesystems
FSfreezeToggle freeze

# Snapshot volumes
for EBS in ${VOLIDS[@]}
do
   logIt "Snapping EBS volume: ${EBS}"
   # Spawn off backgrounded subshells to reduce start-deltas across snap-set
   # Send our snapshot IDs to a FIFO for later use...
   ( \
      aws ec2 create-snapshot --output=text --description ${BKNAME} \
        --volume-id ${EBS} --query SnapshotId > ${FIFO}
   ) &
done

# Set our "Created By" label
GetInvocation

# Read our pipe and apply labels as IDs trickle through the fifo.
for SNAPID in $( cat ${FIFO} )
do
   echo "Tagging snapshot: ${SNAPID}"
   ( \
   aws ec2 create-tags --resource ${SNAPID} --tags \
      Key="Created By",Value="${CREATEMETHOD}" ; \
   aws ec2 create-tags --resource ${SNAPID} --tags \
      Key="Name",Value="AutoBack (${THISINSTID}) $(date '+%Y-%m-%d')" ; \
   aws ec2 create-tags --resource ${SNAPID} --tags \
      Key="Snapshot Group",Value="${DATESTMP} (${THISINSTID})" ; \
   ) &
done

# Unfreeze any enumerated filesystems
echo "Unfreezing..."
FSfreezeToggle unfreeze

# Cleanup on aisle six!
rm ${FIFO}
