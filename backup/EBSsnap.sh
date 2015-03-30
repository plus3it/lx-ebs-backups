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
LOGFILE="${LOGDIR}/backup-${DATE}.log"

# Define how long to keep backups by default
DEFRETAIN="7"					# Value expressed in days
CURCTIME=`date "+%s"`				# Current time in seconds
DAYINSEC="$((60 * 60 * 24))"			# Seconds in a day
KEEPHORIZ="$((${DAYINSEC} * ${DEFRETAIN}))"	# Keep-interval (in seconds)
EXPBEYOND="$((${CURCTIME} - ${KEEPHORIZ}))"	# Expiry horizon (in seconds)
EXPDATE=`date -d @${EXPBEYOND} "+%Y/%m/%d @ %H:%M"`	# Expiry horizon

echo "Host Instance-ID: ${THISINSTID}"
echo "Current time in Seconds: ${CURCTIME}"
echo "Retention Horizon: ${KEEPHORIZ}"
echo "Kill if older: ${EXPBEYOND} (${EXPDATE})"
