#!/bin/env python
import boto3
import getopt
import sys
from optparse import OptionParser


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
        "-s", "--search-string",
            action="store",
            dest="search_string",
            help="String-value to search for (use commas to search for more than one string-value)",
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
ec2Type = options.recovery_instance_type
rescueKey  = options.provisioning_key
snapSearchVal = options.search_string


