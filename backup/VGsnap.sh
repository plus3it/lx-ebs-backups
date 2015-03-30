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

# Get list of physical disks that compose the volume-group
PELIST=$(pvs --noheadings -S vg_name=${TARGVG} -o pv_name 2>&1)
echo ${PELIST} | sed 's/[0-9]*$//'

# GET EBS Volume-list
# aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=i-7396527e --query Volumes[].VolumeId --output text

