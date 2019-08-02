#!/bin/sh
#
# Apply tags to EBS volumes by mapping from local block devices
#
#################################################################
TAGVALU="${1:-UNDEF}"
DEVNODE="${2:-UNDEF}"

# Get instance metadata and set vars
MDHOST="169.254.169.254"
MDDOCPATH="latest/dynamic/instance-identity/document"
MDDOCINFO=$(curl -s http://${MDHOST}/${MDDOCPATH}/)
if [[ -x /usr/bin/jq ]]
then
   export AWS_DEFAULT_REGION=$(echo ${MDDOCINFO} | jq -r .region)
   INSTANCID=$(echo ${MDDOCINFO} | jq -r .instanceId)
else
   echo "The 'jq' utility is not installed. Aborting..." > /dev/stderr
   exit 1
fi


# Convert OS-level dev-path name to EBS attachment-name
function Blk2Xen() {
   local DEVNAME=$(echo $1 | sed 's/xvd/sd/')
   printf ${DEVNAME}
}

function GetEBSvol() {
   local EBSVOLID=$(aws ec2 describe-volumes --filters \
                    "Name=attachment.instance-id,Values=${INSTANCID}" \
                    "Name=attachment.device,Values=${EBSDEV}" \
                    --query "Volumes[].VolumeId" --out text)
   printf ${EBSVOLID}
}

# Apply requested Tag-Value
function TagVol() {
   aws ec2 create-tags --resources ${EBSVOL} --tag "Key=Consistency Group,Value=${TAGVALU}"
}

# Verify that a valid block-device was passed
if [[ ${DEVNODE} = "UNDEF" ]]
then
   echo "Failed to pass a block device. Aborting..." > /dev/stderr
   exit 1
elif [[ ! -b ${DEVNODE} ]]
then
   echo "Error: ${DEVNODE} not a valid block-device. Aborting..." > /dev/stderr
   exit 1
else
   EBSDEV=$(Blk2Xen "${DEVNODE}")
   EBSVOL=$(GetEBSvol ${EBSDEV})
fi

# Apply the tag
printf "Setting 'Consistency Group' tag to \"${TAGVALU}\" on ${EBSVOL}... "
if [[ $(TagVol "${TAGVALU}" ${EBSVOL})$? -eq 0 ]]
then
   echo "Command returned success."
else
   echo "Command returned abnormally." > /dev/stderr
   exit 1
fi
