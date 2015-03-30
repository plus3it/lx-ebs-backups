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

THISINSTID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
DATESTMP=`date "+%Y%m%d%H%M"`
LOGDIR="/var/log/EBSbackup"
LOGFILE="${LOGDIR}/backup-${DATESTMP}.log"

# Define how long to keep backups by default
DEFRETAIN="7"					# Value expressed in days
CURCTIME=`date "+%s"`				# Current time in seconds
DAYINSEC="$((60 * 60 * 24))"			# Seconds in a day
KEEPHORIZ="$((${DAYINSEC} * ${DEFRETAIN}))"	# Keep-interval (in seconds)
EXPBEYOND="$((${CURCTIME} - ${KEEPHORIZ}))"	# Expiry horizon (in seconds)
EXPDATE=`date -d @${EXPBEYOND} "+%Y/%m/%d @ %H:%M"`	# Expiry horizon

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
      COUNT=$((${COUNT} + 1))
   done
}

# Use this method to blindly snap *everything*
function GottaCatchemAll() {
   local ARRCT=${#EBSARRAY[@]}
   local COUNT=0
   SNAPLABEL="$(hostname -s)_${THISINSTID}_bkup-${DATESTMP}"
   while [ ${COUNT} -lt ${ARRCT} ]
   do
      echo "Backup-Tag for ${EBSARRAY[${COUNT}]}: ${SNAPLABEL}"
      COUNT=$((${COUNT} + 1))
   done
}

MultiLog "Host Instance-ID: ${THISINSTID}"
MultiLog "Current time in Seconds: ${CURCTIME}"
MultiLog "Retention Horizon: ${KEEPHORIZ}"
MultiLog "Kill if older: ${EXPBEYOND} (${EXPDATE})"

AllMyDisks
MultiLog "Found: ${#EBSARRAY[@]} attached volumes"
GottaCatchemAll
