import boto3    

ec2client = boto3.client('ec2')

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
                ]
            }
        ]
    )
    print 'Snapshot ' + snap_return['SnapshotId'] + ' started...'
