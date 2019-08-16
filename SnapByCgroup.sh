#!/bin/bash
# shellcheck disable=SC1090,SC2015,SC2013,SC2236
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
BACKOFFSECS=$(( RANDOM % 300 ))
BKNAME="$(hostname -s)_${THISINSTID}-bkup-${DATESTMP}"
FIFO="/tmp/.EBSfifo.$( dd if=/dev/urandom | tr -dc 'a-zA-Z0-9' | \
                       fold -w 10 | head -n 1
                     )"

# Function-abort hooks
trap "exit 1" TERM
export TOP_PID=$$



#########################################
# Put the bulk of our variables into
# sourcable files so they can be easily
# re-used across scripts
#########################################
source "${PROGDIR}/commonVars.env"
source "${PROGDIR}/setcred.sh" && PROGNAME="$( basename "${BASH_SOURCE[0]}" )"

# Print out a basic usage message
function UsageMsg {
   (
      # Special cases
      if [[ ! -z ${MISSINGARGS+x} ]]
      then
         printf "Failed to pass one or more mandatory arguments\n\n"
      elif [[ ! -z ${EXCLUSIVEARGS+x} ]]
      then
         printf "Passed two or more exclusive arguments\n\n"
      fi

      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf "\t-f <LIST_OF_FILESYSTEMS_TO_FREEZE>  \n"
      printf "\t-h # print this message  \n"
      printf "\t-T <MAXIMUM_BACKOFF_TIME>  \n"
      printf "\t-v <VOLUME_GROUP_NAME>  \n"
      echo "  GNU long options:"
      printf "\t--fsname  <LIST_OF_FILESYSTEMS_TO_FREEZE> \n"
      printf "\t--help # print this message  \n"
      printf "\t--max-backoff-time <MAXIMUM_BACKOFF_TIME>  \n"
      printf "\t--vgname <VOLUME_GROUP_NAME>  \n"
   ) >&2
   kill -s TERM " ${TOP_PID}"
}
# Check script invocation-method; set tag-value
function GetInvocation {
   tty -s && CREATEMETHOD="Manually-Initiated Backup" || \
      CREATEMETHOD="Automated Backup"
}

# Create list of filesystems to (un)freeze
function FsSpec {
   # Scoped declaration
   local SPECISFS
   local IDX

   # Let's avoid trying to freeze root filesystems
   if [[ ${1} == / ]] ||
      [[ ${1} == /tmp ]] ||
      [[ ${1} == /var ]] ||
      [[ ${1} == /var/log ]] ||
      [[ ${1} == /var/log/audit ]]
   then
      logIt "Not a good idea to freeze ${1}. Aborting... " 1
      kill -s TERM " ${TOP_PID}"
   fi

   SPECISFS=$(mountpoint "${1}" 2> /dev/null)
   IDX=${#FSLIST[@]}

   if [[ ${SPECISFS} =~ "is a mountpoint" ]]
   then
      logIt "${1} is a valid filesystem. Continuing... " 0
      FSLIST[${IDX}]=${1}
   else
      logIt "${1} is not a valid filesystem. Aborting... " 1
      kill -s TERM " ${TOP_PID}"
   fi
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

	 IDX=$(( IDX + 1 ))
      done
   else
      logIt "No filesystems selected for ${ACTION}" 0
   fi
}


##################
# Option parsing
##################
OPTIONBUFR="$(
      getopt -o f:hT:v: --long fsname:,help,max-backoff-time:,vgname: \
        -n "${PROGNAME}" -- "$@"
   )"
# Note the quotes around '$OPTIONBUFR': they are essential!
eval set -- "${OPTIONBUFR}"

# Parse our flagged args
while true
do
   case "$1" in
      -f|--fsname)
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
      -h|--help)
         UsageMsg
         ;;
      -T|--max-backoff-time)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               BACKOFFSECS=$(( RANDOM % ${2} ))
               shift 2;
               ;;
         esac
	 ;;
      -v|--vgname)
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

# Add a semi-random backoff to reduce likelihood of conflicts with other 
# EC2s' backup-activities
printf "Taking random-pause for %s seconds... " "${BACKOFFSECS}"
sleep "${BACKOFFSECS}" && echo "Continuing"

# Generate list of all EBSes attached to this instance
ALLVOLIDS="$(
      aws ec2 describe-volumes \
         --filters "Name=attachment.instance-id,Values=${THISINSTID}" \
         --query "Volumes[].Attachments[].VolumeId" --output text
   )"

# Check for EBS tagged for named group
logIt "Seeing if any disks match tag ${CONGRP}" 0
COUNT=0
for VOLID in ${ALLVOLIDS}
do
   VOLCHK=$(
         aws ec2 describe-volumes --volume-id "${VOLID}" \
           --filters "Name=tag:Consistency Group,Values=${CONGRP}" \
           --query "Volumes[].Attachments[].VolumeId" --output text
      )

   # Add any relevant tagged-volumes to snap-list
   if [[ ! -z ${VOLCHK} ]]
   then
      VOLIDS[${COUNT}]="${VOLCHK}"
   fi

   # So people don't think we're stuck
   if [[ ${DEBUG} == true ]]
   then
      printf "."
   fi

   COUNT=$(( COUNT + 1 ))
done
echo

# Exit if no EBSes found for consistency-group
if [[ ${#VOLIDS[@]} -eq 0 ]]
 then
   logIt "No volumes found in the requested consistency-group [${CONGRP}]" 1
fi

# Gonna go old school (who the heck uses named pipes in shell scripts???)
if [[ ! -p ${FIFO} ]]
then
   mkfifo "${FIFO}"
fi

# Freeze any enumerated filesystems
FSfreezeToggle freeze

# Snapshot volumes
for EBS in "${VOLIDS[@]}"
do
   logIt "Snapping EBS volume: ${EBS}" 0
   # Spawn off backgrounded subshells to reduce start-deltas across snap-set
   # Send our snapshot IDs to a FIFO for later use...
   ( \
      aws ec2 create-snapshot --output=text --description "${BKNAME}" \
        --volume-id "${EBS}" --query SnapshotId > "${FIFO}"
   ) &
done

# Unfreeze any enumerated filesystems
logIt "Unfreezing any previously-frozen filesystems..." 0
FSfreezeToggle unfreeze

# Set our "Created By" label
GetInvocation

# Read our pipe and apply labels as IDs trickle through the fifo.
for SNAPID in $( cat "${FIFO}" )
do
   logIt "Tagging snapshot: ${SNAPID}" 0

   # Pull volume-id of snapshot's source-volume
   SRCVOL=$(
         aws ec2 describe-snapshots --snapshot-id "${SNAPID}" \
           --query 'Snapshots[].VolumeId' --output text
      )
   export SRCVOL

   # Pull info about snapshot's source-volume
   VOLINFO=$(
         aws ec2 describe-volumes --volume-id "${SRCVOL}" --query \
         'Volumes[].{AvailabilityZone:AvailabilityZone,Attachments:Attachments[].{InstanceId:InstanceId,Device:Device}}'
      )
   ORIGAZ=$(
         echo "${VOLINFO}" | \
         awk  '/ "AvailabilityZone":.*?[^\\]"/ { print $2 }' | \
         sed -e 's/"//g' -e 's/,$//'
      )
   ORIGDEV=$(
         echo "${VOLINFO}" | awk  '/ "Device":.*?[^\\]"/ { print $2 }' | \
         sed -e 's/"//g' -e 's/,$//'
      )
   ORIGINST=$(
         echo "${VOLINFO}" | awk  '/ "InstanceId":.*?[^\\]"/ { print $2 }' | \
         sed -e 's/"//g' -e 's/,$//'
      )

   # Give sixty seconds for all the tagging actions to complete
   timeout 60 bash -c "
         aws ec2 create-tags --resource ${SNAPID} --tags \
            'Key=Created By,Value=${CREATEMETHOD}' ; \
         aws ec2 create-tags --resource ${SNAPID} --tags \
            'Key=Name,Value=AutoBack ('${THISINSTID}') $(date "+%Y-%m-%d")' ; \
         aws ec2 create-tags --resource ${SNAPID} --tags \
            'Key=Snapshot Group,Value=${DATESTMP} (${THISINSTID})' ; \
         aws ec2 create-tags --resource ${SNAPID} --tags \
            'Key=Original Instance,Value=${ORIGINST}' ; \
         aws ec2 create-tags --resource ${SNAPID} --tags \
            'Key=Original Attachment,Value=${ORIGDEV}' ; \
         aws ec2 create-tags --resource ${SNAPID} --tags \
            'Key=Original AZ,Value=${ORIGAZ}' ; \
      " && logIt "Success" 0 || logIt "Failed" 1

   # Should be reduntant, but let's be super-clean
   unset SRCVOL
done

# Cleanup on aisle six!
rm "${FIFO}" || logIt "Failed to remove ${FIFO}" 1
