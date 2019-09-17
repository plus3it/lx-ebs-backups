#!/bin/env python
import boto3
import getopt
import sys
import time
from optparse import OptionParser

# Create initial recovery instance
def mkRecovInst( amiId, ec2Type, provKey, ec2Snet, ec2Az, ec2Label):
    launchResponseJson = ec2client.run_instances(
        ImageId=amiId,
        InstanceType=ec2Type,
        KeyName=provKey,
        MaxCount=1,
        MinCount=1,
        NetworkInterfaces=[
            {
                'DeviceIndex': 0,
                'SubnetId': ec2Snet
            }
        ],
        Placement={
            'AvailabilityZone': ec2Az
        },
        TagSpecifications=[
            {
                'ResourceType': 'instance',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': ec2Label
                    }
                ]
            }
        ]
    )

    return launchResponseJson

# Check recovery-instance's state
def chkInstState(instanceId):
    instanceInfo = ec2client.describe_instance_status(
        InstanceIds=[
            instanceId,
        ],
    )

    if ( instanceInfo.get('InstanceStatuses') ):
##         currentState = instanceInfo.get('InstanceStatuses')[0].get('InstanceState').get('Name')
        currentState = instanceInfo.get('InstanceStatuses')[0].get('InstanceStatus').get('Status')
    else:
        currentState = 'NOT_READY'


    print(currentState)
    return currentState
    

# Make our connections to the service
ec2client = boto3.client('ec2')
ec2resource = boto3.resource('ec2')

# Define option-parsing information
cmdopts = OptionParser()
cmdopts.add_option(
        "-a", "--recovery-ami",
            action="store",
            dest="recovery_ami_id",
            help="AMI ID to launch recovery-instance from",
            type="string"
    )
cmdopts.add_option(
        "-e", "--ebs-type",
            action="store",
            default="gp2",
            dest="ebs_volume_type",
            help="Type of EBS volume to create from snapshots (Default: %default)",
            type="string"
    )
cmdopts.add_option(
        "-k", "--provisioning-key",
            action="store",
            dest="provisioning_key",
            help="SSH key to inject into recovery-instance",
            type="string"
    )
cmdopts.add_option(
        "-n", "--recovery-hostname",
            action="store",
            dest="recovery_hostname",
            help="Name to assign to recovery-instance",
            type="string"
    )
cmdopts.add_option(
        "-S", "--search-string",
            action="store",
            dest="search_string",
            help="String-value to search for (use commas to search for more than one string-value)",
            type="string"
    )
cmdopts.add_option(
        "-s", "--deployment-subnet",
            action="store",
            dest="deployment_subnet",
            help="Subnet ID to deploy recovery-instance into",
            type="string"
    )
cmdopts.add_option(
        "-t", "--instance-type",
            action="store",
            default="t3.large",
            dest="recovery_instance_type",
            help="Instance-type to use for recovery-instance (Default: %default)",
            type="string"
    )
cmdopts.add_option(
        "-z", "--availability-zone",
            action="store",
            dest="availability_zone",
            help="Availability zone to build recovery-instance in (defaults to value found on snapshots)",
            type="string"
    )

# Parse the command options
(options, args) = cmdopts.parse_args()
amiId = options.recovery_ami_id
ebsType  = options.ebs_volume_type
ec2Az = options.availability_zone
ec2Label  = options.recovery_hostname
ec2Snet = options.deployment_subnet
ec2Type = options.recovery_instance_type
provKey  = options.provisioning_key
snapSearchVal = options.search_string

recoveryHost = mkRecovInst(amiId, ec2Type, provKey, ec2Snet, ec2Az, ec2Label)
recoveryHostInstanceStruct = recoveryHost.get('Instances', None)
recoveryHostState = recoveryHostInstanceStruct[0].get('State', None).get('Code', None)
recoveryHostInstanceId = recoveryHostInstanceStruct[0].get('InstanceId', None)

print('Instance ID: ' + recoveryHostInstanceId )

while ( chkInstState(recoveryHostInstanceId) != 'ok' ):
    print('Waiting for ' + recoveryHostInstanceId + 'to come online... ', end = '')
    time.sleep(10)
