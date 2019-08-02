#!/bin/sh
#
# This script is designed to make it easy to capture useful 
# information about attached EBS volumes and save that 
# information to the volumes' tag-sets
# 
#################################################################
PROGNAME="$( basename "${BASH_SOURCE[0]}" )"
PROGDIR="$( dirname "${BASH_SOURCE[0]}" )"
PVS=/sbin/pvs
INSTANCEMETADOC="http://169.254.169.254/latest/dynamic/instance-identity/document/"
INSTANCEMETADAT="$( curl -sL ${INSTANCEMETADOC} )"
INSTANCEID="$( echo ${INSTANCEMETADAT} | \
      python -c 'import json,sys; \
          obj=json.load(sys.stdin);print obj["instanceId"]'
   )"
AWS_DEFAULT_REGION="$( echo ${INSTANCEMETADAT} | \
      python -c 'import json,sys; \
          obj=json.load(sys.stdin);print obj["region"]'
   )"

# Export critical values so sub-shells can use them
export AWS_DEFAULT_REGION

# Lets force the use of credentials from attached IAM Instance-role
source "${PROGDIR}/setcred.sh"

# Check your privilege...
function AmRoot {
   if [ $(whoami) = "root" ]
   then
      echo "Running with privileges"
   else
      echo "Insufficient privileges. Aborting..." > /dev/stderr
      exit 1
   fi
}

# Got LVM?
function CkHaveLVM {
   local HAVELVM

   if [[ $(rpm --quiet -q lvm2)$? -eq 0 ]] && [[ -x ${PVS} ]]
   then
      HAVELVM=TRUE
   else
      HAVELVM=FALSE
   fi

   echo ${HAVELVM}
}

# Return list of attached EBS Volume-IDs
function GetAWSvolIds {
   local VOLIDS
   
   VOLIDS=(
         $( aws ec2 describe-instances --instance-id=${INSTANCEID} --query \
              "Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId" \
              --out text
          )
      )

   echo "${VOLIDS[@]}"
}

# Map attached EBS Volume-ID to sdX device-node
function MapVolIdToDsk {
   local VOLID
   local DEVMAP
   
   VOLID="${1}"
   DEVMAP=$( aws ec2 describe-volumes --volume-id=${VOLID} \
               --query="Volumes[].Attachments[].Device[]" --out text | \
               sed 's/[0-9]*$//'
           )

   echo "${DEVMAP}"
}

# Tack on LVM group-associations where appropriate
function AddLVM2Map {
   local EBSMAPARR
   local LOOPC
   local LVMMAPARR
   local SRCHTOK

   EBSMAPARR=("${!1}")
   LVMMAPARR=("${!2}")

   LOOPC=0
   while [[ ${LOOPC} -le ${#LVMMAPARR[@]} ]]
   do
      SRCHTOK=$(echo ${LVMMAPARR[${LOOPC}]} | cut -d ":" -f 1)

      # This bit of ugliness avoids array re-iteration...
      EBSMAPARR=("${EBSMAPARR[@]/${SRCHTOK}/${LVMMAPARR[${LOOPC}]}}")

      LOOPC=$((${LOOPC} + 1))
   done


   echo ${EBSMAPARR[@]}
}

# Tag-up the EBSes
function TagYerIt {
   # Initialize as local
   local LOOPC
   local MAPPING
   local EBSID
   local DEVNODE
   local LVMGRP
   local DEVMAP

   LOOPC=0
   MAPPING=("${!1}")

   # Iterate over mapping-list...
   while [[ ${LOOPC} -lt ${#MAPPING[@]} ]]
   do
      EBSID=$(echo ${MAPPING[${LOOPC}]} | cut -d ":" -f 1)
      DEVNODE=$(echo ${MAPPING[${LOOPC}]} | cut -d ":" -f 2)
      LVMGRP=$(echo ${MAPPING[${LOOPC}]} | cut -d ":" -f 3)

      # Don't try to set null tags...
      if [ "${LVMGRP}" = "" ]
      then
         LVMGRP="(none)"
      fi

      # Because some some EBSes declare dev-mappings that end in numbers...
      DEVMAP=$( aws ec2 describe-volumes --volume-id=${EBSID} \
         --query="Volumes[].Attachments[].Device[]" --out text )

      printf "Tagging EBS Volume ${EBSID}... "
      aws ec2 create-tags --resources ${EBSID} --tags \
         "Key=Owning Instance,Value=${INSTANCEID}" \
         "Key=Attachment Point,Value=${DEVMAP}" \
         "Key=LVM Group,Value=${LVMGRP}" \
         && echo "Done." || echo "Failed."

      LOOPC=$((${LOOPC} + 1))
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
