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

# Output log-data to multiple locations
function MultiLog() {
   echo "${1}"
   logger -p local0.info -t [C-Group] "${1}"
}

if [ ${CONGRP} = "UNDEF" ]
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

# Snapshot volumes
for EBS in ${VOLIDS}
do
   MultiLog "Snapping EBS volume: ${EBS}"
   SNAPIT=$(aws ec2 create-snapshot --output=text --description ${BKNAME} \
     --volume-id ${EBS} --query SnapshotId)
   aws ec2 create-tags --resource ${SNAPIT} --tags Key="Created By",Value="Automated Backup"
   aws ec2 create-tags --resource ${SNAPIT} --tags Key="Name",Value="AutoBack (${THISINSTID}) $(date '+%Y-%m%-d')"
   aws ec2 create-tags --resource ${SNAPIT} --tags Key="Snapshot Group",Value="${DATESTMP} (${THISINSTID})"
done

