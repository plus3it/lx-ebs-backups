#!/bin/sh
#
# This script is designed to perform consistent backups of
# - Selected EBS volumes (referenced by volume-id)
# - Mounted filesystems  (referenced by fully-qualified directory-path)
# - LVM volumes (referenced by VGNAME/LVNAME path-specification)
#
# Update the "DEFRETAIN" variable to change how long to keep backups
#
#
# Dependencies:
# - Generic: See the top-level README_dependencies.md for script dependencies
#
# License:
# - This script released under the Apache 2.0 OSS License
#
######################################################################
WHEREAMI=`readlink -f ${0}`
SCRIPTDIR=`dirname ${WHEREAMI}`
TARGVG=${1:-UNDEF}

# Put the bulk of our variables into an external file so they
# can be easily re-used across scripts
source ${SCRIPTDIR}/commonVars.env

# Check to see if a Volume group was passed...
if [ ${TARGVG} == "UNDEF" ]
then
   echo "No volume-group specified. Aborting"
   exit 1

else

   VALIDVG=$(vgs ${TARGVG} > /dev/null 2>&1)$?
   # Check to see if passed Volume Group name is valid...
   if [ ${VALIDVG} -ne 0 ]
   then
      echo "Specified VG not found on system. Aborting"
      exit 1
   fi
fi

# Create array of disks underpinning selected VG
function PVtoArray() {
   local COUNT=0
   for PV in `pvs --noheadings -S vg_name=${TARGVG} -o pv_name 2>&1 | \
      sed 's/[0-9]*$//' | sort -u`
   do
      PVARRAY[${COUNT}]="${PV}"
      local COUNT=$((${COUNT} +1))
   done
}

# Create array of attached EBS volumes
function EVolToArray() {
   local COUNT=0
   for VODLID in `aws ec2 describe-volumes --filters \
      "Name=attachment.instance-id,Values=${THISINSTID}" --query \
      "Volumes[].Attachments[].{VID:VolumeId,HDD:Device}" | \
       awk '{printf("%s:%s\n",$1,$2)}'`
   do
      EBSARRAY[${COUNT}]="${VODLID}"
      local COUNT=$((${COUNT} +1))
   done
}

PVtoArray
EVolToArray

# Just testing that array-stuffing works
echo ${PVARRAY[@]}
echo ${EBSARRAY[@]}

# KVP-list of AWS volume-attachment info
## aws ec2 describe-volumes --filters \
##    "Name=attachment.instance-id,Values=${THISINSTID}" --query \
##    "Volumes[].Attachments[].{VID:VolumeId,HDD:Device}" --output text

# Iterate PVARRAY to find elements from EBSARRAY, then merge

# Iterate merged array to snapshot only EBSes in VG
