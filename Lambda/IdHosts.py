import boto3    

ec2client = boto3.client('ec2')

# Finda all instances with 'BackMeUp' tag
response = ec2client.describe_instances(
    Filters=[
            {
                'Name': 'tag-key',
                'Values': ['BackMeUp']
            },
        ]
    )

# Intialize list-var
instance_list = []

# Populate instance list-var
for reservation in response['Reservations']:
    for instance in reservation['Instances']:
        instance_list.append(instance['InstanceId'])

print instance_list
