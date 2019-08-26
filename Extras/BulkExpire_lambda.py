import sys
import datetime
import boto3

#Lambda expects this...
def lambda_handler(event, context):
    # Make our connections to the service
    ec2client = boto3.client('ec2')

    expire_days = event['ExpireDays']
    search_key = event['SearchKey']
    search_val = event['SearchVal']

    try:
        ## Supplementation validation of command options
        # Enforce passing of a search_key value
        if search_key == '':
            cmdopts.error("A tag-name must be specified (via -t/--tag-name) for search")

        # If we pass a null value, assume safe to search for *any* value
        if search_val == '':
            search_val = '*'

        # Do some time-deltas
        today = datetime.date.today()
        datefilter = today - datetime.timedelta(days=expire_days)
        print('Searching for snapshots older than deletion threshold-date ['
              +
              datefilter.strftime("%Y-%m-%d")
              +
              ']... '
        )

        # Narrow the list of candidate-snapshots by tag-name
        snapshots = ec2client.describe_snapshots(
            Filters=[
                {
                    'Name': 'tag:' + search_key,
                    'Values': [
                        '*' + search_val + '*'
                    ]
                }
            ]
            )

        # Boto3 doesn't let you '<= DATE' filter: gotta iterate
        for snapshot in snapshots['Snapshots']:
            snap_created = snapshot['StartTime']
            snap_id = snapshot['SnapshotId']

            if snap_created.strftime('%Y%m%d') <= datefilter.strftime("%Y%m%d"):
                print(
                    'Snapshot %s created %s is %s days old or older: DELETING... ' %
                    (snap_id, snap_created.strftime('%Y-%m-%d'), expire_days),
                    end=''
                )

                # Try to nuke the snap...
                delstruct = ec2client.delete_snapshot(SnapshotId=snap_id)

                # Print the request-status
                if delstruct['ResponseMetadata']['HTTPStatusCode'] == 200:
                    print('Delete succeded')
                else:
                    print('Delete failed')
                sys.exit()

            else:
                print(
                    'Snapshot %s created %s is not %s days old or older: keeping' %
                    (snap_id, snap_created.strftime('%Y-%m-%d'), expire_days)
                )

    except:
        print('One or more tasks failed')
