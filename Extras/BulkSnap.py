#!/bin/env python
import boto3
import datetime
import getopt
import sys
from optparse import OptionParser


# Make our connections to the service
ec2client = boto3.client("ec2")
ec2resource = boto3.resource("ec2")
scriptUser = boto3.client("sts").get_caller_identity()["Arn"]

# Set defaults
bulk_tag_value = "Bulk Backup"
scriptDate = datetime.datetime.now().strftime("%Y%m%d")


# Get list of EBS mappings
def get_dev_maps(blockdev_list=[]):
    for reservation in filtered_response["Reservations"]:
        for instance in reservation["Instances"]:
            blockdev_list.append(instance["BlockDeviceMappings"])

    return blockdev_list


# Walk EBS mappings to get volume-IDs
def get_vol_list(dev_list=[], *args):
    volids_list = []

    for top in dev_list:
        for next in top:
            ebs_struct = next["Ebs"]
            volids_list.append(ebs_struct["VolumeId"])

    return volids_list


# Define option-parsing information
cmdopts = OptionParser()
cmdopts.add_option(
    "-t",
    "--instance-tag-name",
    action="store",
    type="string",
    default="BackMeUp",
    dest="bulk_tag_name",
    help="Name of tag to search for (default: %default)",
)
cmdopts.add_option(
    "-v",
    "--instance-tag-value",
    action="store",
    type="string",
    default="Bulk Backup",
    dest="bulk_tag_value",
    help="Value of 'BackupName' tag to apply to snapshots (default: %default)",
)

# Parse the command options
(options, args) = cmdopts.parse_args()
bulk_tag_name = options.bulk_tag_name
bulk_tag_value = options.bulk_tag_value


# Finda all instances with named-tag
filtered_response = ec2client.describe_instances(
    Filters=[
        {"Name": "tag-key", "Values": [bulk_tag_name]},
    ]
)

# Iterate volume-list to create snapshots
for volume in get_vol_list(get_dev_maps()):
    # grab info about volume to be snapped
    volume_info = ec2resource.Volume(volume).attachments[0]
    volume_owner = volume_info["InstanceId"]
    volume_dev = volume_info["Device"]

    # Grab EC2 association for original volume
    instance_info = ec2client.describe_instances(InstanceIds=[volume_owner])[
        "Reservations"
    ][0]["Instances"][0]
    instance_az = instance_info["Placement"]["AvailabilityZone"]

    snap_return = ec2client.create_snapshot(
        Description=volume_owner + "-BulkSnap-" + scriptDate,
        VolumeId=volume,
        TagSpecifications=[
            {
                "ResourceType": "snapshot",
                "Tags": [
                    {"Key": "Created By", "Value": scriptUser.split(":", 5)[-1]},
                    {"Key": "Name", "Value": bulk_tag_value},
                    {"Key": "Original Attachment", "Value": volume_dev},
                    {"Key": "Original AZ", "Value": instance_az},
                    {"Key": "Original Hostname", "Value": "NOT AVAILABLE"},
                    {"Key": "Original Instance", "Value": volume_owner},
                    {"Key": "Snapshot Group", "Value": "Bulk"},
                ],
            }
        ],
    )

    print("Snapshot " + str(snap_return["SnapshotId"]) + " started...")
