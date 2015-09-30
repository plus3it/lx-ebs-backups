#!/bin/sh
#
# Get a list of EBSes attached to this system and present them
# in a formatted list.
#
#################################################################
MDHOST="169.254.169.254"
MDDOCPATH="latest/dynamic/instance-identity/document"
MDDOCINFO=$(curl -s http://${MDHOST}/${MDDOCPATH}/)
INSTANCID=$(echo ${MDDOCINFO} | jq -r .instanceId)
AWSREGION=$(echo ${MDDOCINFO} | jq -r .region)
AWSAVAILZ=$(echo ${MDDOCINFO} | jq -r .availabilityZone)

RED='\033[0;31m'
NC='\033[0m'

IFS=$'\n'
MYDISKS=($(
   aws --region ${AWSREGION} ec2 describe-volumes --filters \
   "Name=attachment.instance-id,Values=${INSTANCID}" \
   --query "Volumes[].{VID:VolumeId,SZ:Size,VTYP:VolumeType}" \
   --out text
        ))
unset IFS

printf "%s\t%s\t%s\n" "Size (GiB)" Volume-ID Volume-Type

LOOP=0
while [[ ${LOOP} -lt ${#MYDISKS[@]} ]]
do
   DISKINFO=${MYDISKS[${LOOP}]}
   printf "%10s\t${RED}%s${NC}\t%s\n" ${DISKINFO}
   ((LOOP+=1))
done
