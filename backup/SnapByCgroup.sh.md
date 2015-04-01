# Description
This script is designed to perform consistent backups of a set of EBSes within a specified consistency-group. The script takes one argument - the name of the consistency-group assigned to one or more EBS volumes. The script will then request that all EBSes in the target-set will be snapshotted as close to simultaneously as the AWS tools allow (there may be a few milliseconds seconds delay between start times)

# Dependencies:
- All EBSes to be backed up as a consistency-group must be tagged:
  - Tag-name:  "Consistency Group"
  - Tag-value: (user-selectable)

# Usage
Invoke the script as follows:

&nbsp;&nbsp;&nbsp;SnapByCgroup.sh "&lt;CONSISTENCY_GROUP_NAME&gt;"

After invocation all members of the EBS-set should show up in the AWS console as having the same snapshot start-time value.
