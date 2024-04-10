#!/bin/bash
# shellcheck disable=SC2155,SC1090,SC2207,SC1004,SC2236
#
# Get a list of EBSes attached to this system and present them
# in a formatted list.
#
#################################################################
export PROGNAME="$( basename "${BASH_SOURCE[0]}" )"
export PROGDIR="$( dirname "${BASH_SOURCE[0]}" )"
MDHOST="169.254.169.254"
MDDOCPATH="latest/dynamic/instance-identity/document"
MDDOCINFO=$(curl -s http://${MDHOST}/${MDDOCPATH}/)

# Lets force the use of credentials from attached IAM Instance-role
source PROGNAME="$( basename "${BASH_SOURCE[0]}" )"

# Extract data from JSON-struct
function ExtractFromJson {
   local JSON_ELEM
   JSON_ELEM="${1}"

   if [[ ! -z ${JSON_ELEM} ]]
   then
      echo "${MDDOCINFO}" | \
        python -c 'import json,sys; \
          obj=json.load(sys.stdin); \
          print obj["'"${JSON_ELEM}"'"]'
   else
      logIt "No credential-element was specified. Aborting... " 1
   fi
}

# Set further needed values...
export AWSREGION=$( ExtractFromJson "region" )
export INSTANCID=$( ExtractFromJson "instanceId" )

# Color-formatting flags
RED='\033[0;31m'
NC='\033[0m'

if [[ $(test -r /proc/cmdline)$? -eq 0 ]]
then
   if [[ $(grep -q "xen_blkfront.sda_is_xvda=1" /proc/cmdline)$? -eq 0 ]]
   then
      logIt "Root-dev should be /dev/xvda" 0
   else
      printf "%sWARNING: Reported block devices may " "${RED}"
      printf "not be accurate%s\n" "${NC}"
   fi
fi
   

# Grab instance's disks and stuff them into an array
IFS=$'\n'
MYDISKS=($(
   aws --region "${AWSREGION}" ec2 describe-volumes --filters \
   "Name=attachment.instance-id,Values=${INSTANCID}" \
   --query "Volumes[].{VID:VolumeId,SZ:Size,VTYP:VolumeType}" \
   --out text
        ))
unset IFS

printf "%-10s\t%-22s\t%-11s\t%s\n" "Size (GiB)" "EBS Volume-ID" Volume-Type Block-Device

LOOP=0
while [[ ${LOOP} -lt ${#MYDISKS[@]} ]]
do
   DISKINFO=( "${MYDISKS[${LOOP}]}" )
   BLOCKDEV=$(
         readlink -f "$(
               aws --region "${AWSREGION}" ec2 \
                 describe-volumes --volume-id "${DISKINFO[1]}" \
                 --query "Volumes[].Attachments[].Device[]" \
                 --out text
            )"
      )
   printf "%10s\t%s%-22s%s\t%11s\t%s\n" "${DISKINFO[@]}" "${RED}" "${NC}" "${BLOCKDEV}"
   ((LOOP+=1))
done
