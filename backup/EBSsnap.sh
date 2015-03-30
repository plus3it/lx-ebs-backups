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

# Put the bulk of our variables into an external file so they
# can be easily re-used across scripts
source ${SCRIPTDIR}/globalVars.env


# Determine if LOGFILE is usable by this user;
# - if not, try to create and set a usable location
# - if can't, change LOGFILE to dump to world-writable location
#   (e.g., /var/tmp)
# NOT YET FUNCTIONAL
function SetLogDest() {
   echo "" > /dev/null
}

# Output log-data to multiple locations
function MultiLog() {
   echo "${1}"
   logger -p local0.info -t [EBSsnap] "${1}"
   # We'll add this later...
   #    This only works if ${LOGFILE} exists and invoking-user has
   #    permissions to log location.
   #    Uncomment when SetLogDest() is functional.
   # echo "${1}" >> ${LOGFILE}
}

# Enumerate *all* the disks attached to this instance
function AllMyDisks() {
   local COUNT=0
   for ELEMENT in `aws ec2 describe-volumes --filters \
      Name=attachment.instance-id,Values=${THISINSTID} --query \
      Volumes[].VolumeId --output text`
   do
      EBSARRAY[${COUNT}]=${ELEMENT}
      local COUNT=$((${COUNT} + 1))
   done
}

# Use this method to blindly snap *everything*
function GottaCatchemAll() {
   local ARRCT=${#EBSARRAY[@]}
   local COUNT=0
   SNAPLABEL="$(hostname -s)_${THISINSTID}_bkup-${DATESTMP}"
   while [ ${COUNT} -lt ${ARRCT} ]
   do
    # echo "Backup-Tag for ${EBSARRAY[${COUNT}]}: ${SNAPLABEL}"
      SNAPNID=$(aws ec2 create-snapshot --output=text --description \
         ${SNAPLABEL} --volume-id ${EBSARRAY[${COUNT}]} --query SnapshotId)
      MultiLog "New snapshot ID is ${SNAPNID}"
      TAGIT=$(aws ec2 create-tags --resource ${SNAPNID} --tags Key='Creation Process',Value='Automated Backup Script')
      local COUNT=$((${COUNT} + 1))
   done
}

MultiLog "Host Instance-ID: ${THISINSTID}"
MultiLog "Current time in Seconds: ${CURCTIME}"
MultiLog "Retention Horizon: ${KEEPHORIZ}"
MultiLog "Kill if older: ${EXPBEYOND} (${EXPDATE})"

AllMyDisks
MultiLog "Found: ${#EBSARRAY[@]} attached volumes"
GottaCatchemAll
