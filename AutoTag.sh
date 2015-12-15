#!/bin/sh
#
# This script is designed to make it easy to capture useful 
# information about attached EBS volumes and save that 
# information to the volumes' tag-sets
# 
#################################################################
INSTANCEINFO="http://169.254.169.254/latest/dynamic/instance-identity/document/"
INSTANCEID=$(curl -sL ${INSTANCEINFO} | awk '/instanceId/{print $3}' | \
             sed -e 's/",$//' -e 's/"//')
AWS_DEFAULT_REGION=$(curl -sL ${INSTANCEINFO} | \
                     awk '/region/{print $3}' | \
                     sed -e 's/",$//' -e 's/"//')
PVS=/sbin/pvs

export AWS_DEFAULT_REGION

# Check your privilege...
function AmRoot() {
   if [ $(whoami) = "root" ]
   then
      echo "Running with privileges"
   else
      echo "Insufficient privileges. Aborting..." > /dev/stderr
      exit 1
   fi
}

# Got LVM?
function CkHaveLVM() {
   if [[ $(rpm --quiet -q lvm2)$? -eq 0 ]] && [[ -x ${PVS} ]]
   then
      local HAVELVM=TRUE
   else
      local HAVELVM=FALSE
   fi

   echo ${HAVELVM}
}

# Return list of attached EBS Volume-IDs
function GetAWSvolIds(){
   local VOLIDS=($(aws ec2 describe-instances --instance-id=${INSTANCEID}\
                 --query "Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId" \
                 --out text))

   echo "${VOLIDS[@]}"
}

# Map attached EBS Volume-ID to sdX device-node
function MapVolIdToDsk(){
   local VOLID="${1}"
   local DEVMAP=$(aws ec2 describe-volumes --volume-id=${VOLID} \
                  --query="Volumes[].Attachments[].Device[]" --out text | \
                  sed 's/[0-9]*$//')

   echo "${DEVMAP}"
}

# Tack on LVM group-associations where appropriate
function AddLVM2Map(){
   local EBSMAPARR=("${!1}")
   local LVMMAPARR=("${!2}")

   local LOOPC=0
   while [[ ${LOOPC} -le ${#LVMMAPARR[@]} ]]
   do
      local SRCHTOK=$(echo ${LVMMAPARR[${LOOPC}]} | cut -d ":" -f 1)

      # This bit of ugliness avoids array re-iteration...
      EBSMAPARR=("${EBSMAPARR[@]/${SRCHTOK}/${LVMMAPARR[${LOOPC}]}}")

      local LOOPC=$((${LOOPC} + 1))
   done


   echo ${EBSMAPARR[@]}
}

# Tag-up the EBSes
function TagYerIt(){
   local MAPPING=("${!1}")

   local LOOPC=0
   while [[ ${LOOPC} -lt ${#MAPPING[@]} ]]
   do
      local EBSID=$(echo ${MAPPING[${LOOPC}]} | cut -d ":" -f 1)
      local DEVNODE=$(echo ${MAPPING[${LOOPC}]} | cut -d ":" -f 2)
      local LVMGRP=$(echo ${MAPPING[${LOOPC}]} | cut -d ":" -f 3)

      # Don't try to set null tags...
      if [ "${LVMGRP}" = "" ]
      then
         LVMGRP="(none)"
      fi

      # Because some some EBSes declare dev-mappings that end in numbers...
      local DEVMAP=$(aws ec2 describe-volumes --volume-id=${EBSID} \
                     --query="Volumes[].Attachments[].Device[]" --out text)

      printf "Tagging EBS Volume ${EBSID}... "
      aws ec2 create-tags --resources ${EBSID} --tags \
         "Key=Owning Instance,Value=${INSTANCEID}" \
         "Key=Attachment Point,Value=${DEVMAP}" \
         "Key=LVM Group,Value=${LVMGRP}" \
         && echo "Done." || echo "Failed."

      local LOOPC=$((${LOOPC} + 1))
   done
}


#######################
## Main program flow
#######################

AmRoot

printf "Determining attached EBS volume IDs... "
EBSVOLIDS=$(GetAWSvolIds) && echo "Done." || echo "Failed."

printf "Mapping EBS volume IDs to local devices... "
LOOP=0
for EBSVOL in ${EBSVOLIDS}
do
   EBSDEV=$(MapVolIdToDsk ${EBSVOL})
   EBSMAP[${LOOP}]="${EBSVOL}:${EBSDEV}"
   LOOP=$((${LOOP} + 1))
done  && echo "Done." || echo "Failed."

if [ "$(CkHaveLVM)" = "TRUE" ]
then
   echo "Looking for LVM object... "
   LVOBJ=($(${PVS} --noheadings -o pv_name,vg_name --separator ':' | sed 's/[0-9]*:/:/'))

   echo "Updating EBS/device mappings"
   MAPPINGS=($(AddLVM2Map "EBSMAP[@]" "LVOBJ[@]"))
else
   LVOBJ=""
   MAPPINGS=(${EBSMAP[@]})
fi

TagYerIt "MAPPINGS[@]"
