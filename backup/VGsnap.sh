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

# Starter Variables
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/AWScli/bin
WHEREAMI=`readlink -f ${0}`
SCRIPTDIR=`dirname ${WHEREAMI}`

# Put the bulk of our variables into an external file so they
# can be easily re-used across scripts
source ${SCRIPTDIR}/commonVars.env

# SCRIPT Variables
TARGVG=${1:-UNDEF}
BKNAME="$(hostname -s)_${THISINSTID}-bkup-${DATESTMP}"

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
      "Volumes[].Attachments[].VolumeId" --output text`
   do
      EBSARRAY[${COUNT}]="${VODLID}"
      local COUNT=$((${COUNT} +1))
   done
}

# Create list of filesystems hosted on VG
function GetFSlist() {
   local COUNT=0
   for FSNAME in `mount | awk '/\/'${TARGVG}'-/{print $3}'`
   do
      FSLISTARR[${COUNT}]="${FSNAME}"
      local COUNT=$((${COUNT} +1))
   done
}
  

PVtoArray
EVolToArray
GetFSlist

echo ${EBSARRAY[@]}

# Freeze filesystems
for FS in ${FSLISTARR[@]}
do
   printf "Freezing ${FS}... "
   fsfreeze -f ${FS} && echo
done

# Snapshot volumes
for EBS in ${EBSARRAY[@]}
do
   echo "Snapping EBS volume: ${EBS}"
   SNAPIT=$(aws ec2 create-snapshot --output=text --description ${BKNAME} \
     --volume-id ${EBS} --query SnapshotId)
   aws ec2 create-tags --resource ${SNAPIT} --tags Key="Created By",Value="Automated Backup"
done

# Unfreeze hosted filesystems
for FS in ${FSLISTARR[@]}
do
   printf "Unfreezing ${FS}... "
   fsfreeze -u ${FS} && echo
done
