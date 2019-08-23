#!/bin/env python
import boto3
import getopt
import sys

# Make our connections to the service
ec2client = boto3.client('ec2')
ec2resource = boto3.resource('ec2')

# How to invoke the script
def usage():
    print('Usage: ' + sys.argv[0] + ' [GNU long option] [option] ...')
    print('  Options:')
    print('\t-h print this message')
    print('\t-t <BACKUP_TAG_NAME>')
    print('  GNU long options:')
    print('\t--help print this message')
    print('\t--instance-tag <BACKUP_TAG_NAME>')


# Get list of EBS mappings
def get_dev_maps(blockdev_list = []):
    for reservation in filtered_response['Reservations']:
        for instance in reservation['Instances']:
            blockdev_list.append(instance['BlockDeviceMappings'])

    return blockdev_list;


# Walk EBS mappings to get volume-IDs
def get_vol_list(dev_list = [], *args):
    volids_list = []

    for top in dev_list:
        for next in top:
            ebs_struct = next['Ebs']
            volids_list.append(ebs_struct['VolumeId'])

    return volids_list;

# Check our argument-list
criteria_str = '" as the instance-tag match-criteria.'
if len(sys.argv[1:]) == 0:
    bulk_tag = 'BackMeUp'
    print('No arguments passed to script: using "' + bulk_tag + criteria_str)
else:
    try:
        optlist, args = getopt.getopt(
              sys.argv[1:],
              "t:h",
              [
                  "help",
                  "instance-tag="
              ]
           )
    except getopt.GetoptError as err:
        # print help information and exit:
        usage()
        sys.exit(2)

    for opt, arg in optlist:
       if opt in ("-h", "--help"):
            usage()
            sys.exit()
       elif opt in ( '-t', '--instance-tag='):
           bulk_tag = arg
           print('Using "' + bulk_tag + criteria_str)
       else:
           assert False, "unhandled option"

# Finda all instances with named-tag
filtered_response = ec2client.describe_instances(
    Filters=[
            {
                'Name': 'tag-key',
                'Values': [bulk_tag]
            },
        ]
    )

# Iterate volume-list to create snapshots
for volume in get_vol_list(get_dev_maps()):

    # grab info about volume to be snapped
    volume_info = ec2resource.Volume(volume).attachments[0]
    volume_owner = volume_info['InstanceId']
    volume_dev = volume_info['Device']

    snap_return = ec2client.create_snapshot(
        Description='Bulk-snapshot (' + volume_owner + ')',
        VolumeId=volume,
        TagSpecifications=[
            {
                'ResourceType': 'snapshot',
                'Tags': [
                    {
                        'Key': 'BackupName',
                        'Value': 'Bulk Backup'
                    },
                    {
                        'Key': 'Owning Instance',
                        'Value': volume_owner
                    },
                    {
                        'Key': 'Instance Attachment',
                        'Value': volume_dev
                    },
                ]
            }
        ]
    )

    print('Snapshot ' + str(snap_return['SnapshotId']) + ' started...')
