#!/bin/env python
import boto3
import getopt
import sys


# Make our connections to the service
ec2client = boto3.client('ec2')
ec2resource = boto3.resource('ec2')

expiry_days = 30
snap_size = 0
tag_name = ''
tag_value = ''

response = ec2client.describe_snapshots()


# How to invoke the script
def usage():
    print('Usage: ' + sys.argv[0] + ' [GNU long option] [option] ...')
    print('  Options:')
    print('\t-d <EXPIRE_OLDER_THAN_DAYS>\t\t(MANDATORY)')
    print('\t-h print this message')
    print('\t-s <BACKUP_SIZE>\t\t\t(OPTIONAL)')
    print('\t-t <BACKUP_TAG_NAME>\t\t\t(MANDATORY)')
    print('\t-v <BACKUP_TAG_VALUE>\t\t\t(OPTIONAL)')
    print('  GNU long options:')
    print('\t--days-old <EXPIRE_OLDER_THAN_DAYS>\t(MANDATORY)')
    print('\t--help print this message')
    print('\t--snapshot-size <BACKUP_SIZE>\t\t(OPTIONAL)')
    print('\t--tag-name <BACKUP_TAG_NAME>\t\t(MANDATORY)')
    print('\t--tag-value <BACKUP_TAG_VALUE>\t\t(OPTIONAL)')

# Check our argument-list
criteria_str = '" as the instance-tag match-criteria.'
if len(sys.argv[1:]) == 0:
    # print help information and exit:
    usage()
    sys.exit(1)
else:
    try:
        optlist, args = getopt.getopt(
              sys.argv[1:],
              "d:hs:t:v:",
              [
                  "days-old=",
                  "help",
                  "snapshot-size=",
                  "tag-name=",
                  "tag-value="
              ]
           )
    except getopt.GetoptError as err:
        # print help information and exit:
        usage()
        sys.exit(2)

    # Iterate the argument-list
    for opt, arg in optlist:
       if opt in ("-h", "--help"):
            usage()
            sys.exit()
       elif opt in ( '-d', '--days-old='):
           expiry_days = arg
       elif opt in ( '-s', '--snapshot-size='):
           snap_size = arg
       elif opt in ( '-t', '--tag-name='):
           tag_name = arg
       elif opt in ( '-v', '--tag-value='):
           tag_value = arg
       else:
           assert False, "unhandled option"

    # Fail on missing mandatories

response = ec2client.describe_snapshots()

