#!/bin/sh
#
# Get a list of EBSes attached to this system and present them
# in a formatted list.
#
#################################################################
PROGNAME="$( basename "${BASH_SOURCE[0]}" )"
PROGDIR="$( dirname "${BASH_SOURCE[0]}" )"
MDHOST="169.254.169.254"
MDDOCPATH="latest/dynamic/instance-identity/document"
MDDOCINFO=$(curl -s http://${MDHOST}/${MDDOCPATH}/)

# Lets force the use of credentials from attached IAM Instance-role
source "${PROGDIR}/setcred.sh"

# Pull useful info from meta-data docment
if [[ -x /usr/bin/jq ]]
then
   INSTANCID=$(echo ${MDDOCINFO} | jq -r .instanceId)
   AWSREGION=$(echo ${MDDOCINFO} | jq -r .region)
   AWSAVAILZ=$(echo ${MDDOCINFO} | jq -r .availabilityZone)
else
   logIt "The 'jq' utility is not installed. Aborting... " 1
fi

# Color-formatting flags
RED='\033[0;31m'
NC='\033[0m'

if [[ $(test -r /proc/cmdline)$? -eq 0 ]]
then
   if [[ $(grep -q "xen_blkfront.sda_is_xvda=1" /proc/cmdline)$? -eq 0 ]]
   then
      logIt "Root-dev should be /dev/xvda" 0
   else
      printf "${RED}WARNING: Reported block devices may not be accurate${NC}\n"
   fi
fi
   

# Grab instance's disks and stuff them into an array
IFS=$'\n'
MYDISKS=($(
   aws --region ${AWSREGION} ec2 describe-volumes --filters \
   "Name=attachment.instance-id,Values=${INSTANCID}" \
   --query "Volumes[].{VID:VolumeId,SZ:Size,VTYP:VolumeType}" \
   --out text
        ))
unset IFS

printf "%-10s\t%-22s\t%-11s\t%s\n" "Size (GiB)" "EBS Volume-ID" Volume-Type Block-Device

LOOP=0
while [[ ${LOOP} -lt ${#MYDISKS[@]} ]]
do
   DISKINFO=(${MYDISKS[${LOOP}]})
   BLOCKDEV=$(readlink -f $(aws --region ${AWSREGION} ec2 \
                describe-volumes --volume-id ${DISKINFO[1]} \
                --query "Volumes[].Attachments[].Device[]" \
                --out text))
   printf "%10s\t${RED}%-22s${NC}\t%11s\t%s\n" ${DISKINFO[@]} ${BLOCKDEV}
   ((LOOP+=1))
done
