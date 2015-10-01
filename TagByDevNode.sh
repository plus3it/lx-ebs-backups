#!/bin/sh
#
# Apply tags to EBS volumes by mapping from local block devices
#
#################################################################
DEVNODE="${1:-UNDEF}"

if [[ ${DEVNODE} = "UNDEF" ]]
then
   echo "Failed to pass a block device. Aborting..." > /dev/stderr
   exit 1
elif [[ ! -b ${DEVNODE} ]]
then
   echo "Error: ${DEVNODE} not a valid block-device. Aborting..." > /dev/stderr
   exit 1
fi
