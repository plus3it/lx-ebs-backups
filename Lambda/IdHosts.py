import boto3    

ec2client = boto3.client('ec2')
ec2resource = boto3.resource('ec2')

# Finda all instances with 'BackMeUp' tag
filtered_response = ec2client.describe_instances(
    Filters=[
            {
                'Name': 'tag-key',
                'Values': ['BackMeUp']
            },
        ]
    )

# Intialize list-var
instance_list = []
blockdev_list = []
volids_list = []

# Populate instance list-var
for reservation in filtered_response['Reservations']:
    for instance in reservation['Instances']:
        instance_list.append(instance['InstanceId'])
        blockdev_list.append(instance['BlockDeviceMappings'])

# Walk blockdev_list to get volume-IDs
for top in blockdev_list:
    for next in top:
        ebs_struct = next['Ebs']
        volids_list.append(ebs_struct['VolumeId'])

# Iterate volume-list to create snapshots
for volume in volids_list:

    # grab info about volume to be snapped
    volume_info = ec2resource.Volume(volume).attachments[0]
    volume_owner = volume_info['InstanceId']
    volume_dev = volume_info['Device']

    snap_return = ec2client.create_snapshot(
        Description='Bulk-snapshot test',
        VolumeId=volume,
        TagSpecifications=[
            {
                'ResourceType': 'snapshot',
                'Tags': [
                    {
                        'Key': 'BackupName',
                        'Value': 'Test'
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

    print 'Snapshot ' + snap_return['SnapshotId'] + ' started...'
