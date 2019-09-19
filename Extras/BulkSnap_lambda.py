import boto3
import datetime
import sys


# Lambda expects this...
def lambda_handler(event, context):
    # Make our connections to the service
    ec2client = boto3.client('ec2')
    ec2resource = boto3.resource('ec2')
    scriptUser = boto3.client('sts').get_caller_identity()['Arn']

    # Set some key var-vals
    scriptDate = datetime.datetime.now().strftime('%Y%m%d')

    # Map 'event' as EC2 instance-tag search-string
    search_tag = event['SearchTag']

    # Customize backup-naming of snapshots as appropriate
    if event['CustomBackupName']:
        custom_backup_name = event['CustomBackupName']
    else:
        custom_backup_name = 'Bulk Backup'


    # Wrap it all in a try/except
    try:
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


        # Find all instances with named-tag
        filtered_response = ec2client.describe_instances(
            Filters=[
                    {
                        'Name': 'tag-key',
                        'Values': [ 'BackMeUp', 'BulkBackup', search_tag ]
                    },
                ]
            )

        # Iterate volume-list to create snapshots
        for volume in get_vol_list(get_dev_maps()):

            # grab info about volume to be snapped
            volume_info = ec2resource.Volume(volume).attachments[0]
            volume_owner = volume_info['InstanceId']
            volume_dev = volume_info['Device']

            # Grab EC2 association for original volume
            instance_info = ec2client.describe_instances( InstanceIds=[ volume_owner ])['Reservations'][0]['Instances'][0]
            instance_az = instance_info['Placement']['AvailabilityZone']

            snap_return = ec2client.create_snapshot(
                Description = volume_owner + '-BulkSnap-' + scriptDate,
                VolumeId = volume,
                TagSpecifications=[
            {
                'ResourceType': 'snapshot',
                'Tags': [
                    {
                        'Key': 'Created By',
                        'Value': scriptUser.split(':', 5)[-1]
                    },
                    {
                        'Key': 'Name',
                        'Value': custom_backup_name
                    },
                    {
                        'Key': 'Original Attachment',
                        'Value': volume_dev
                    },
                    {
                        'Key': 'Original AZ',
                        'Value': instance_az
                    },
                    {
                        'Key': 'Original Hostname',
                        'Value': 'NOT AVAILABLE'
                    },
                    {
                        'Key': 'Original Instance',
                        'Value': volume_owner
                    },
                    {
                        'Key': 'Snapshot Group',
                        'Value': 'Bulk'
                    },
                ]
            }
        ]
            )

            print('Snapshot ' + str(snap_return['SnapshotId']) + ' started...')

    except:
        print('One or more tasks failed')
