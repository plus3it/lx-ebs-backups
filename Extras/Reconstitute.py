#!/bin/env python
import boto3
import getopt
import sys
import time
from optparse import OptionParser

# Create initial recovery-instance
def mkRecovInst(amiId, ec2Type, provKey, ec2Snet, ec2Az, ec2Label):
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


# Monitor instance state-transition
def ec2StateChange(recoveryHostInstanceId,targState,targStatus):
    while True:
        try:
           instanceState = chkInstState(recoveryHostInstanceId)
           if ( instanceState == targStatus ):
               break
           else:
               print('Waiting for ' + recoveryHostInstanceId, end='')
               print(' to reach ' + targState + '... ', end = '')
               time.sleep(10)
        except:
            print('pending')
            time.sleep(10)

    return


# Stop recovery-instance
def stopRecovInst(instanceId):
    print('\nRequesting stop of ' + instanceId + '... ', end = '')

    instanceInfo = ec2client.stop_instances(
        InstanceIds=[
            instanceId,
        ],
    )

    return


# Check recovery-instance's state
def chkInstState(instanceId):
    instanceStatus = ec2client.describe_instance_status(
                         InstanceIds=[
                             instanceId
                         ]
                     )
    instanceInfo =  ec2client.describe_instances(
                        InstanceIds=[
                            instanceId
                        ]
                    )
    instanceState = instanceInfo['Reservations'][0]['Instances'][0]['State']['Name']

    if ( instanceState == 'running' ):
        if ( instanceStatus.get('InstanceStatuses')[0].get('InstanceStatus').get('Status') ):
            currentState = instanceStatus.get('InstanceStatuses')[0].get('InstanceStatus').get('Status')
        else:
            currentState = 'TRANSITIONING'
    else:
        currentState = instanceState


    print(currentState)
    return currentState


# Get snapshot information
def getSnapInfo(snapSearchVal):
    snapInfo = ec2client.describe_snapshots(
       Filters=[
          {
              'Name': 'tag:Snapshot Group',
              'Values': [
                 snapSearchVal
              ]
          }
       ]
    )

    return snapInfo


# Extract tags from snapshot attributes
def snapTagsToAttribs(snapSearchVal):
    snapReturn = {}

    for snapInfo in getSnapInfo(snapSearchVal)['Snapshots']:
        snapAttribs = {}
        snapId = snapInfo['SnapshotId']

        for tags in snapInfo['Tags']:
            tagList = list(tags.values())
            snapAttribs[tagList[0]] = tagList[1]

        snapReturn[snapId] = snapAttribs

    return snapReturn


# Reconstitute EBSes from snapshots
def snapsToEbses(buildAz,ebsType,snapAttribs):

    ebsList = []

    # Iterate over snapshot-list
    for snapshot in snapAttribs:
        # Get useful info from snapshot's data
        origInstance = snapAttribs[snapshot]['Original Instance']
        origAttach = snapAttribs[snapshot]['Original Attachment']

        # Let user know what we're doing
        print('Creating ' + ebsType + ' volume from ' + snapshot + '... ', end='')

        # Create the volume
        newVolInfo = ec2client.create_volume(
                AvailabilityZone=buildAz,
                SnapshotId=snapshot,
                VolumeType=ebsType,
                TagSpecifications=[
                    {
                        'ResourceType': 'volume',
                        'Tags': [
                            {
                                'Key': 'Original Instance',
                                'Value': origInstance
                            },
                            {
                                'Key': 'Original Attachment',
                                'Value': origAttach
                            },
                        ]
                    },
                ]
            )

        print(newVolInfo['VolumeId'])
        ebsList.append(newVolInfo)

##    print(ebsList)
    return ebsList


# Reconstitute EBSes from snapshots
def rebuildToAz(ec2Az,snapAttribs):

    if ec2Az == '':
        arbSnap = next(iter(snapAttribs))
        rebuildAz = snapAttribs[arbSnap]['Original AZ']
    else:
        rebuildAz = ec2Az

    print('Building resources in: ' + rebuildAz + '\n')
    return rebuildAz


# Detach rootEBS from instance
def killRootEBS(instance):

    # Extract target-EBS from instance-ID
    tgtEbs = ec2client.describe_instances(
        InstanceIds=[
            instance
        ],
    )['Reservations'][0]['Instances'][0]['BlockDeviceMappings'][0]['Ebs']['VolumeId']

    # Print action-message
    print('\nDetaching volume ' + tgtEbs + ' from instance ' + instance + '...')

    # Request detach
    ec2client.detach_volume(InstanceId=instance,VolumeId=tgtEbs)

    # Wait for EBS to come free
    while ( ec2client.describe_volumes(VolumeIds=[ tgtEbs ])['Volumes'][0]['State'] != 'available' ):
        volumeState = ec2client.describe_volumes(VolumeIds=[ tgtEbs ])['Volumes'][0]['State']
        print('Volume ' + tgtEbs + ' is still ' + volumeState + '...')
        time.sleep(10)

    # If you're happy and you know it...
    print('Volume ' + tgtEbs + ' successfully detached')

    # Print action-message
    print('\nCleaning up volume ' + tgtEbs +  '...')

    # Nuke the volume
    ec2client.delete_volume(VolumeId=tgtEbs) 

    # Wait for it to go bye-bye
    while True:
        try:
            ec2client.describe_volumes(VolumeIds=[ tgtEbs ])
            print('Waiting for ' + tgtEbs + ' to die...')
        except:
            print('Successfully deleted ' + tgtEbs)
            break

    return

# Attach reconstituted volumes
def reattachVolumes(instance,ebsInfo):
    
    print('\nGetting ready to attach reconstituted EBS volumes')
    # Iterate over the EBS info-structure
    for ebsObject in ebsInfo:
        newVolume = ebsObject['VolumeId']

        # Fetch our attachment-point
        attachPoint = next(item for item in ebsObject['Tags'] if item['Key'] == 'Original Attachment')['Value']

        # Inform user of action
        print('Attaching ' + newVolume + ' to ' + instance + ' at ', end='')
        print(attachPoint + '...')

        # Perform attachment
        attachOutput = ec2client.attach_volume(
            Device=attachPoint,
            InstanceId=instance,
            VolumeId=newVolume
        )

    return attachOutput


# Power on restored instance
def powerOnInstance(instanceId):

    print('\nRequesting final power-on of ' + instanceId + '... ', end = '')

    instanceInfo = ec2client.start_instances(
        InstanceIds=[
            instanceId,
        ],
    )

    return instanceInfo


# Get connection-info
def getConnectInfo(instanceId):
    instanceInfo = ec2client.describe_instances(InstanceIds=[instanceId])['Reservations'][0]['Instances'][0]
    instancePrivName = instanceInfo['PrivateDnsName']
    instancePrivIp = instanceInfo['PrivateIpAddress']
    # instancePubName = instanceInfo['PublicDnsName']

    print('Attach to recovery-instance at ' + instancePrivName, end='')
    print(' (' + instancePrivIp + ')')

    return


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
            help="SSH key to inject into recovery-instance [**NOT YET IMPLEMENTED**]",
            type="string"
    )
cmdopts.add_option(
        "-P", "--power-on",
            action="store_true",
            dest="recovery_power",
            default=False,
            help="Power on the recovered instance"
    )
cmdopts.add_option(
        "-n", "--recovery-hostname",
            action="store",
            dest="recovery_hostname",
            help="Name to assign to recovery-instance (as shown in EC2 console/CLI)",
            type="string"
    )
cmdopts.add_option(
        "-r", "--root-snapid",
            action="store",
            dest="root_snapid",
            help="Snapshot-ID of original instance's root EBS (if not part of snapshot-group) [**NOT YET IMPLEMENTED**]",
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
            default="",
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
powerOn = options.recovery_power
provKey  = options.provisioning_key
rootSnap = options.root_snapid
snapSearchVal = options.search_string


# Surface snapshots' tags
snapAttribs = snapTagsToAttribs(snapSearchVal)

# Decide which AZ to reconstitute to
buildAz = rebuildToAz(ec2Az,snapAttribs)

# Rebuild EBSes
restoredEbsInfo = snapsToEbses(buildAz,ebsType,snapAttribs)

# Start recovery-instance and extract requisite data-points from process
recoveryHost = mkRecovInst(amiId, ec2Type, provKey, ec2Snet, buildAz, ec2Label)
recoveryHostInstanceStruct = recoveryHost.get('Instances', None)
recoveryHostState = recoveryHostInstanceStruct[0].get('State', None).get('Code', None)
recoveryHostInstanceId = recoveryHostInstanceStruct[0].get('InstanceId', None)

# Printout recvoery-instance ID
print('\nLaunched instance (' + recoveryHostInstanceId + '): ', end = '')

# Track lauch-status
ec2StateChange(recoveryHostInstanceId, 'online', 'ok')

# Issue stop-request
stopRecovInst(recoveryHostInstanceId)

## # Need to delay: queries break during some parts of stat-transition
## time.sleep(10)

# Wait for instance to stop
ec2StateChange(recoveryHostInstanceId, 'offline', 'stopped')

# Detach recovery-instance's default root-EBS
killRootEBS(recoveryHostInstanceId)

# Attach all the reconstituted volumes to the recovery-instance
reattachVolumes(recoveryHostInstanceId,restoredEbsInfo)

# Start recovery-instance if requested
if powerOn:
    powerOnInstance(recoveryHostInstanceId)
    ec2StateChange(recoveryHostInstanceId, 'online', 'ok')
    getConnectInfo(recoveryHostInstanceId)

