#!/bin/env python
import boto3
import datetime
import getopt
import sys
from optparse import OptionParser

# pylint: skip-file

# Make our connections to the service
ec2client = boto3.client("ec2")
ec2resource = boto3.resource("ec2")


# Define option-parsing information
cmdopts = OptionParser()
cmdopts.add_option(
    "-d",
    "--days-old",
    action="store",
    type="int",
    dest="exp_days",
    default=30,
    help="Minumum snapshot-age to expire (default: %default days)",
)
cmdopts.add_option(
    "-t",
    "--tag-name",
    action="store",
    type="string",
    dest="tag_key",
    default="",
    help="Snapshot-tag key-name",
)
cmdopts.add_option(
    "-v",
    "--tag-value",
    action="store",
    type="string",
    dest="tag_val",
    default="",
    help="Snapsot-tag value (substring-match; may be omitted)",
)

# Parse the command options
(options, args) = cmdopts.parse_args()
exp_days = options.exp_days
tag_key = options.tag_key
tag_val = options.tag_val


## Supplementation validation of command options
# Enforce passing of a tag_key value
if tag_key == "":
    cmdopts.error("A tag-name must be specified (via -t/--tag-name) for search")

# If we pass a null value, assume safe to search for *any* value
if tag_val == "":
    tag_val == "*"

# Do some time-deltas
today = datetime.date.today()
datefilter = today - datetime.timedelta(days=exp_days)
print(
    "Searching for snapshots older than deletion threshold-date ["
    + datefilter.strftime("%Y-%m-%d")
    + "]... "
)

# Narrow the list of candidate-snapshots by tag-name
snapshots = ec2client.describe_snapshots(
    Filters=[{"Name": "tag:" + tag_key, "Values": ["*" + tag_val + "*"]}]
)

# Boto3 doesn't let you '<= DATE' filter: gotta iterate
for snapshot in snapshots["Snapshots"]:
    snap_created = snapshot["StartTime"]
    snap_id = snapshot["SnapshotId"]

    if snap_created.strftime("%Y%m%d") <= datefilter.strftime("%Y%m%d"):
        print(
            "Snapshot %s created %s is %s days old or older: DELETING... "
            % (snap_id, snap_created.strftime("%Y-%m-%d"), exp_days),
            end="",
        )

        # Try to nuke the snap...
        delstruct = ec2client.delete_snapshot(SnapshotId=snap_id)

        # Print the request-status
        if delstruct["ResponseMetadata"]["HTTPStatusCode"] == 200:
            print("Delete succeded")
        else:
            print("Delete failed")
        sys.exit()

    else:
        print(
            "Snapshot %s created %s is not %s days old or older: keeping"
            % (snap_id, snap_created.strftime("%Y-%m-%d"), exp_days)
        )
