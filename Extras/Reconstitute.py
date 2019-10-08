#!/bin/env python
"""
This script automates the recovery of failed EC2 instances from previously
captured snapshots. Invoke script with --help flag or read project README
for detailed usage-instructions.
"""

import sys
import re
import time
import base64
from optparse import OptionParser
import boto3

def recovery_ec2_get_az(ec2_az, snapshot_attributes):
    """
    Print AZ actions will take place in
    """

    if ec2_az == '':
        exemplar_snapshot = next(iter(snapshot_attributes))
        rebuild_az = snapshot_attributes[exemplar_snapshot]['Original AZ']
    else:
        rebuild_az = ec2_az

    print('Building resources in: ' + rebuild_az + '\n')
    return rebuild_az


def recovery_ec2_make():
    """
    Launch an instance to attach reconstitute EBS volumes to
    """

    launch_info_struct = EC2_CLIENT.run_instances(
        ImageId=AMI_ID,
        InstanceType=EC2_TYPE,
        KeyName=PROV_KEY,
        MaxCount=1,
        MinCount=1,
        NetworkInterfaces=[
            {
                'DeviceIndex': 0,
                'SubnetId': EC2_SUBNET
            }
        ],
        Placement={
            'AvailabilityZone': EC2_AZ
        },
        TagSpecifications=[
            {
                'ResourceType': 'instance',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': EC2_LABEL
                    }
                ]
            }
        ]
    )

    return launch_info_struct


def recovery_ec2_check_state(ec2_id):
    """
    Check recovery-instance's state
    """

    try:
        ec2_status = EC2_CLIENT.describe_instance_status(
            InstanceIds=[
                ec2_id
            ]
        )
    except EC2_CLIENT.exceptions.ClientError:
        raise ValueError('ERROR: Failed fetching status from ' + ec2_id)

    try:
        ec2_info = EC2_CLIENT.describe_instances(
            InstanceIds=[
                ec2_id
            ]
        )
    except EC2_CLIENT.exceptions.ClientError:
        raise ValueError('ERROR: Failed querying info from ' + ec2_id)

    ec2_state = ec2_info['Reservations'][0]['Instances'][0]['State']['Name']

    if ec2_state == 'running':
        try:
            current_state = ec2_status['InstanceStatuses'][0]['InstanceStatus']['Status']
        except IndexError:
            current_state = 'TRANSITIONING'
    else:
        current_state = ec2_state


    print(current_state)
    return current_state


def recovery_ec2_monitor_transition(ec2_id, target_state, target_status):
    """
    Monitor instance state-transition
    """
    while True:
        try:
            ec2_state = recovery_ec2_check_state(ec2_id)
            if ec2_state == target_status:
                break
            else:
                print('Waiting for ' + ec2_id, end='')
                print(' to reach ' + target_state + '... ', end='')
                time.sleep(10)
        except ValueError:
            print('pending')
            time.sleep(10)


def recovery_ec2_power_on(ec2_id):
    """
    Power on restored instance
    """

    print('\nRequesting final power-on of ' + ec2_id + '... ', end='')

    ec2_info = EC2_CLIENT.start_instances(
        InstanceIds=[
            ec2_id,
        ],
    )

    return ec2_info


def recovery_ec2_stop(ec2_id):
    """
    Stop recovery-instance
    """
    print('\nRequesting stop of ' + ec2_id + '... ', end='')

    EC2_CLIENT.stop_instances(
        InstanceIds=[
            ec2_id,
        ],
    )


def recovery_ec2_get_connect(ec2_id):
    """
    Get connection-info
    """

    ec2_info = EC2_CLIENT.describe_instances(
        InstanceIds=[ec2_id]
    )['Reservations'][0]['Instances'][0]
    ec2_private_name = ec2_info['PrivateDnsName']
    ec2_private_ip = ec2_info['PrivateIpAddress']
    # ec2_public_name = ec2_info['PublicDnsName']

    print('Attach to recovery-instance at ' + ec2_private_name, end='')
    print(' (' + ec2_private_ip + ')')


def recovery_ec2_add_access(ec2_id, security_groups):
    """
    Attach security-groups to recovery-instance
    """

    security_group_list = security_groups.split(',')

    if len(security_group_list) <= 5:
        print()
        for security_group in security_group_list:
            print('Attempting to add security-group ' + security_group, end='')
            print(' to ' + ec2_id + '... ', end='')
            try:
                EC2_CLIENT.modify_instance_attribute(
                    Groups=[security_group],
                    InstanceId=ec2_id,
                )
                print('Success')
            except EC2_CLIENT.exceptions.ClientError:
                print('ERROR: Failed adding security group ' + security_group \
                + ' to ' + ec2_id)
    else:
        print('List of security-groups too long. Skipping')


def ebs_get_snap_info(snap_search_value):
    """
    Get information from targeted-snapshots
    """
    snapshot_info = EC2_CLIENT.describe_snapshots(
        Filters=[
            {
                'Name': 'tag:'+SNAP_SEARCH_TAG,
                'Values': [
                    snap_search_value
                ]
            }
        ]
    )

    # Make sure we actually found snapshots to reconstitute...
    if not snapshot_info['Snapshots']:
        sys.exit("Found no matching snapshots to reconstitute: aborting")

    return snapshot_info


def ebs_snap_reconstitute(build_az, ebs_type, snapshot_attributes):
    """
    Reconstitute EBSes from snapshots
    """

    ebs_list = []

    # Iterate over snapshot-list
    for snapshot in snapshot_attributes:
        # Get useful info from snapshot's data
        original_ec2 = snapshot_attributes[snapshot][SNAP_EC2_ID_TAG]
        original_device = snapshot_attributes[snapshot][SNAP_DEV_TAG]

        # Let user know what we're doing
        print('Creating ' + ebs_type + ' volume from ' + snapshot + '... ', end='')

        # Create the volume
        volume_info = EC2_CLIENT.create_volume(
            AvailabilityZone=build_az,
            SnapshotId=snapshot,
            VolumeType=ebs_type,
            TagSpecifications=[
                {
                    'ResourceType': 'volume',
                    'Tags': [
                        {
                            'Key': 'Original Instance',
                            'Value': original_ec2
                        },
                        {
                            'Key': 'Original Attachment',
                            'Value': original_device
                        },
                    ]
                },
            ]
        )

        print(volume_info['VolumeId'])
        ebs_list.append(volume_info)

    return ebs_list


def ebs_snap_tags_to_attribs(snap_search_value):
    """
    Extract tag-data from snapshot attributes
    """
    snap_attribute_return = {}

    for snapshot_info in ebs_get_snap_info(snap_search_value)['Snapshots']:
        snap_attributes = {}
        snapshot_id = snapshot_info['SnapshotId']

        for tags in snapshot_info['Tags']:
            tag_list = list(tags.values())
            snap_attributes[tag_list[0]] = tag_list[1]

        snap_attribute_return[snapshot_id] = snap_attributes

    return snap_attribute_return


def ebs_reconstitution_attach(instance, ebs_info):
    """
    Attach reconstituted volumes to recovery-instance
    """

    print('\nGetting ready to attach reconstituted EBS volumes')
    # Iterate over the EBS info-structure
    for ebs_object in ebs_info:
        new_volume = ebs_object['VolumeId']

        # Fetch our attachment-point
        attach_point = next(
            item for item in ebs_object['Tags']
            if item['Key'] == 'Original Attachment'
        )['Value']

        # Inform user of action
        print('Attaching ' + new_volume + ' to ' + instance + ' at ', end='')
        print(attach_point + '...')

        # Perform attachment
        attachment_output = EC2_CLIENT.attach_volume(
            Device=attach_point,
            InstanceId=instance,
            VolumeId=new_volume
        )

    return attachment_output


def userdata_inject(recovery_ec2_id, userdata_content):
    """
    Inject recovery-userData into recovery-instance
    """

    # Push userdata to recovery EC2
    try:
        print('\nInjecting userData into recovery-instance')

        EC2_CLIENT.modify_instance_attribute(
            InstanceId=recovery_ec2_id,
            UserData={
                'Value': userdata_content
            },
        )
    except EC2_CLIENT.exceptions.ClientError:
        sys.exit('ERROR: Failed to set userData on recovery-instance')


def userdata_clone(recovery_ec2_id, snap_attributes):
    """
    Copy userData from source-instance to recovery-instance
    """

    # Fetch userData from original Instance
    try:
        orig_instance_id = snap_attributes[next(iter(snap_attributes))]['Source Instance Id']

        # Get userdata from original EC2
        userdata_base64 = EC2_CLIENT.describe_instance_attribute(
            Attribute='userData',
            InstanceId=orig_instance_id
        )['UserData']['Value']

        # Decode the userData
        userdata_text = base64.b64decode(userdata_base64)

    except EC2_CLIENT.exceptions.ClientError:
        print('ERROR: Unable to determine source instance-Id from snapshot attributes')

    # Push userdata to recovery EC2
    userdata_inject(recovery_ec2_id, userdata_text)


def userdata_read_file(user_data_file):
    """
    Read in external userData content
    """

    # See if file can be opened; bail if not
    try:
        file_handle = open(user_data_file, 'r')
        file_content = file_handle.read()
    except FileNotFoundError:
        sys.exit('\nABORTING: Failed while opening ' + user_data_file)

    return file_content


def nuke_root_ebs(instance):
    """
    Detach rootEBS from instance and delete
    """

    # Extract target-EBS from instance-ID
    target_ebs = EC2_CLIENT.describe_instances(
        InstanceIds=[
            instance
        ],
    )['Reservations'][0]['Instances'][0]['BlockDeviceMappings'][0]['Ebs']['VolumeId']

    # Print action-message
    print('\nDetaching volume ' + target_ebs + ' from instance ' + instance + '...')

    # Request detach
    EC2_CLIENT.detach_volume(InstanceId=instance, VolumeId=target_ebs)

    # Wait for EBS to come free
    while EC2_CLIENT.describe_volumes(VolumeIds=[target_ebs])['Volumes'][0]['State'] != 'available':
        volume_state = EC2_CLIENT.describe_volumes(VolumeIds=[target_ebs])['Volumes'][0]['State']
        print('Volume ' + target_ebs + ' is still ' + volume_state + '...')
        time.sleep(10)

    # If you're happy and you know it...
    print('Volume ' + target_ebs + ' successfully detached')

    # Print action-message
    print('\nCleaning up volume ' + target_ebs +  '...')

    # Nuke the volume
    EC2_CLIENT.delete_volume(VolumeId=target_ebs)

    # Wait for it to go bye-bye
    while True:
        try:
            EC2_CLIENT.describe_volumes(VolumeIds=[target_ebs])
            print('Waiting for ' + target_ebs + ' to die...')
        except EC2_CLIENT.exceptions.ClientError:
            print('Successfully deleted ' + target_ebs)
            break


def validate_ami_id():
    """
    Make sure the requested AMI-ID is a valid-string and exists in the region
    """

    # Valid-length check
    if len(AMI_ID) == 12:
        match = re.match(r'(ami-)([a-f0-9]{8})', AMI_ID)
    elif len(AMI_ID) == 21:
        match = re.match(r'(ami-)([a-f0-9]{17})', AMI_ID)
    else:
        sys.exit('ERROR: AMI ' + AMI_ID + ' is not a valid length. Aborting...')


    # Regex failure
    if match is None:
        sys.exit('ERROR: AMI ' + AMI_ID + ' contains invalid characters. Aborting...')
    # Regex success
    elif AMI_ID == match.group(0):
        try:
            EC2_CLIENT.describe_images(
                ImageIds=[
                    AMI_ID
                ]
            )
        except EC2_CLIENT.exceptions.ClientError:
            sys.exit('ERROR: AMI ' + AMI_ID + ' not found. Aborting...')
    else:
        sys.exit('ERROR: AMI ' + AMI_ID + ' is an invalid value. Aborting...')


## def validate_instance_type():
##     """
##     Check requested instance-type against those available in-region
##     """
##
##     print(
##         'Information about available instance-types can be retrieved from
##         a region-url like: \
##         \
##         https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json \
##         \
##         then pulling data from the url returned in the \
##         \
##         .offers.AmazonEC2.currentVersionUrl \
##         \
##         attribute. However, this is a long, expensive process ill-suited to \
##         a simple validity-check exercise.'
##     )


def validate_provision_key():
    """
    Make sure the requested provisioning-key exists in the account
    """

    try:
        EC2_CLIENT.describe_key_pairs(KeyNames=[PROV_KEY])
    except EC2_CLIENT.exceptions.ClientError:
        sys.exit(
            'ERROR: requested provisioning-key [' + PROV_KEY + \
            '] not found. Aborting...'
        )


def validate_security_group():
    """
    Validate the passed security-group
    """

    security_group_list = SECURITY_GROUPS.split(',')

    for security_group in security_group_list:
        # Valid-length check
        if len(security_group) == 11:
            match = re.match(r'(sg-)([a-f0-9]{8})', security_group)
        elif len(security_group) == 20:
            match = re.match(r'(sg-)([a-f0-9]{17})', security_group)
        else:
            sys.exit(
                'ERROR: requested security-group [' \
                + security_group + \
                '] is not a valid string-length. Aborting...'
            )

        # Regex failure
        if match is None:
            sys.exit(
                'ERROR: security-group [' \
                + security_group + \
                '] contains invalid characters. Aborting...'
            )
        elif security_group == match.group(0):
            try:
                EC2_CLIENT.describe_security_groups(
                    GroupIds=[security_group]
                )
            except EC2_CLIENT.exceptions.ClientError:
                sys.exit(
                    'ERROR: Requested security-group [' \
                    + security_group + \
                    '] does not exist. Aborting...'
                )


def validate_subnet(subnet_id):
    """
    Validate the passed subnet
    """

    # Extract availability-zone from subnet
    try:
        subnet_struct = EC2_CLIENT.describe_subnets(
            SubnetIds=[
                subnet_id
            ]
        )
    except EC2_CLIENT.exceptions.ClientError:
        sys.exit('\nERROR: Subnet ' + subnet_id + ' not found. Aborting...')

    subnet_az = subnet_struct['Subnets'][0]['AvailabilityZone']

    return subnet_az


# Make our connections to the service
EC2_CLIENT = boto3.client('ec2')

# Define option-parsing information
CMD_OPTS = OptionParser()
CMD_OPTS.add_option(
    "-a", "--recovery-ami",
    action="store",
    dest="recovery_ami_id",
    help="AMI ID to launch recovery-instance from",
    type="string"
    )
CMD_OPTS.add_option(
    "-e", "--ebs-type",
    action="store",
    default="gp2",
    dest="ebs_volume_type",
    help="Type of EBS volume to create from snapshots (Default: %default)",
    type="string"
    )
CMD_OPTS.add_option(
    "-k", "--provisioning-key",
    action="store",
    dest="provisioning_key",
    help="SSH key to inject into recovery-instance [**NOT YET IMPLEMENTED**]",
    type="string"
    )
CMD_OPTS.add_option(
    "-P", "--power-on",
    action="store_true",
    dest="recovery_power",
    default=False,
    help="Power on the recovered instance (Default: %default)"
    )
CMD_OPTS.add_option(
    "-n", "--recovery-hostname",
    action="store",
    dest="recovery_hostname",
    help="Name to assign to recovery-instance (as shown in EC2 console/CLI)",
    type="string"
    )
CMD_OPTS.add_option(
    "-r", "--root-snapid",
    action="store",
    dest="root_snapid",
    help=(
        "Snapshot-ID of original instance's root EBS (if not part of \
        snapshot-group) [**NOT YET IMPLEMENTED**]"
    ),
    type="string"
    )
CMD_OPTS.add_option(
    "-S", "--search-string",
    action="store",
    dest="search_string",
    help="String-value to search for (use commas to search for more than one string-value)",
    type="string"
    )
CMD_OPTS.add_option(
    "-s", "--deployment-subnet",
    action="store",
    dest="deployment_subnet",
    help="Subnet ID to deploy recovery-instance into",
    type="string"
    )
CMD_OPTS.add_option(
    "-t", "--instance-type",
    action="store",
    default="t3.large",
    dest="recovery_instance_type",
    help="Instance-type to use for recovery-instance (Default: %default)",
    type="string"
    )
CMD_OPTS.add_option(
    "-U", "--user-data-file",
    dest="userdata_file",
    help="Inject userData from selected file"
    )
CMD_OPTS.add_option(
    "-u", "--user-data-clone",
    action="store_true",
    default=False,
    dest="userdata_bool",
    help="Attempt to clone userData from source instance (Default: %default)"
    )
CMD_OPTS.add_option(
    "-x", "--access-groups",
    action="store",
    dest="recovery_sg",
    help="Security-groups to assign to recovery-instance",
    type="string"
    )
CMD_OPTS.add_option(
    "--alt-search-tag",
    action="store",
    default="Snapshot Group",
    dest="search_tag",
    help="Snapshot-attribute used to find grouped-snapshots (Default: '%default')",
    type="string"
    )
CMD_OPTS.add_option(
    "--alt-ec2-tag",
    action="store",
    default="Original Instance",
    dest="original_ec2_tag",
    help="Snapshot-attribute containing original EC2 ID (Default: '%default')",
    type="string"
    )
CMD_OPTS.add_option(
    "--alt-device-tag",
    action="store",
    default="Original Attachment",
    dest="original_device_tag",
    help="Snapshot-attribute containing original EBS attachment-info (Default: '%default')",
    type="string"
    )

# Parse the command options
(OPTIONS, ARGS) = CMD_OPTS.parse_args()
AMI_ID = OPTIONS.recovery_ami_id
EBS_TYPE = OPTIONS.ebs_volume_type
EC2_LABEL = OPTIONS.recovery_hostname
EC2_SUBNET = OPTIONS.deployment_subnet
EC2_TYPE = OPTIONS.recovery_instance_type
POWER_ON = OPTIONS.recovery_power
PROV_KEY = OPTIONS.provisioning_key
ROOT_SNAP = OPTIONS.root_snapid
SECURITY_GROUPS = OPTIONS.recovery_sg
SNAP_SEARCH_TAG = OPTIONS.search_tag
SNAP_SEARCH_VAL = OPTIONS.search_string
SNAP_EC2_ID_TAG = OPTIONS.original_ec2_tag
SNAP_DEV_TAG = OPTIONS.original_device_tag
USERDATA_BOOL = OPTIONS.userdata_bool
USERDATA_FILE = OPTIONS.userdata_file

# Handle mutually-exclusive options
if USERDATA_BOOL and USERDATA_FILE:
    sys.exit('ERROR: `-u` and `-U` are mutually-exclusive options')

# Test file-access early so we can save some time/effort
if USERDATA_FILE:
    USERDATA_CONTENT = userdata_read_file(USERDATA_FILE)

# Check validity of requested AMI
validate_ami_id()

# Ensure reconstitution-subnet is valid
EC2_AZ = validate_subnet(EC2_SUBNET)

# Ensure requested security-group(s) exist
validate_security_group()

# Check validity of requested provisioning-key
validate_provision_key()

# Surface snapshots' tags
SNAP_ATTRIBS = ebs_snap_tags_to_attribs(SNAP_SEARCH_VAL)

# Decide which AZ to reconstitute to
BUILD_AZ = recovery_ec2_get_az(EC2_AZ, SNAP_ATTRIBS)

# Rebuild EBSes
RESTORED_EBS_INFO = ebs_snap_reconstitute(BUILD_AZ, EBS_TYPE, SNAP_ATTRIBS)

# Start recovery-instance and extract requisite data-points from process
RECOVERY_HOST_INSTANCE_ID = recovery_ec2_make()['Instances'][0]['InstanceId']

# Printout recvoery-instance ID
print('\nLaunched instance (' + RECOVERY_HOST_INSTANCE_ID + '): ', end='')

# Track lauch-status
recovery_ec2_monitor_transition(RECOVERY_HOST_INSTANCE_ID, 'online', 'ok')

# Issue stop-request
recovery_ec2_stop(RECOVERY_HOST_INSTANCE_ID)

## # Need to delay: queries break during some parts of stat-transition
## time.sleep(10)

# Wait for instance to stop
recovery_ec2_monitor_transition(RECOVERY_HOST_INSTANCE_ID, 'offline', 'stopped')

# Detach recovery-instance's default root-EBS
nuke_root_ebs(RECOVERY_HOST_INSTANCE_ID)

# Attach all the reconstituted volumes to the recovery-instance
ebs_reconstitution_attach(RECOVERY_HOST_INSTANCE_ID, RESTORED_EBS_INFO)

# Attach security-groups to instance
if SECURITY_GROUPS:
    recovery_ec2_add_access(RECOVERY_HOST_INSTANCE_ID, SECURITY_GROUPS)

# Inject userData from file if requested
if USERDATA_FILE:
    userdata_inject(RECOVERY_HOST_INSTANCE_ID, USERDATA_CONTENT)

# Inject cloned userData if requested
if USERDATA_BOOL:
    userdata_clone(RECOVERY_HOST_INSTANCE_ID, SNAP_ATTRIBS)

# Start recovery-instance if requested
if POWER_ON:
    recovery_ec2_power_on(RECOVERY_HOST_INSTANCE_ID)
    recovery_ec2_monitor_transition(RECOVERY_HOST_INSTANCE_ID, 'online', 'ok')
    recovery_ec2_get_connect(RECOVERY_HOST_INSTANCE_ID)
