# Functionality
This script is designed to create EBS volumes from snapshots previously created using the `SnapByCgroup.sh` script. This script takes several arguments:

- **Snapshot Group**: This argument is *mandatory*. A "snapshot group" is group of one or more snapshots created by the `SnapByCgroup.sh` script. This argument is prepended with either the `-g` or `--snapgrp` commandline switch.
- **Availability Zone**: This argument is optional. If this argument is not given, the restored EBS volumes will be created within the same AZ as the instance the script is executed from. This argument is prepended with either the `-a` or `--az` commandline switch. Legal values are any availability zones in the same region as the instance the script is run from.
- **EBS Type**: This argument is optional. If this argument is not given, the restored EBS volumes will be created as (standard) magnetic volumes. This argument is prepended with either the `-t` or `--ebstype` commandline switch. Legal values are `standard`, `gp2` and `io1`
- **Provisioned IOPs**: This argument is mandatory if the **EBS TYPE** has been selected as `io1`. This argument is prepended with either the `-i` or `--iops` commandline switch. Valid values are restricted to integers and will depend on the size of the volume(s) being restored.

Assuming all mandatory arguments and valid optional arguments have been specified, this script will then create EBS(es) from volume snapshots matching the passed "`Snapshot Group`" attribute. The restored EBS(es) will be standard magnetic volumes unless the **EBS Type** option has been specified and will be created in the invoking host's availability zone unless the **Availability Zone** option has been specified.

# Assumptions/Requirements
This script assumes that all of the elements of a consistency group share a common "`Snapshot Group`" attribute. While it is expected that the "`Snapshot Group`" attribute's value will be of the form:

&nbsp;&nbsp;&nbsp;YYYYMMDDHHMM (&lt;INSTANCE_ID&gt;)

It is not, however, a hard requirement. This expectation is simply derived from the "`Snapshot Group`" attribute set by this script's associated backup script(s). Any "`Snapshot Group`" value will do, so long as:
- All members of an EBS consistency-group share a common "`Snapshot Group`" attribute.
- All "`Snapshot Group`" attributes are unique across snapshot-groups within an AWS region

# Usage
To use this script, invoke in a manner similar to:

&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)"`

or

&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)" -a us-east-1a`

or

&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)" -t gp2`

or

&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)" -t io1 -i 600`

The quotations shown above are only required if using "`Snapshot Group`" attributes that contain spaces or other characters that may break shell-globbing.

# Follow-on Tasks
Once this script has created the recovery EBS volumes, it will be necessary to attach them to an instance. To primary use-cases are anticipated: file-level and "bare-metal" style restores.

## "Bare-metal" Restore
"Bare-metal" restores can be done in two main ways: restore-in-place and parallel-restore.
### Restore-In-Place
In this scenario, the recovery volumes are recovered to the original, presumably broken instance. Steps for doing so are as follows:

1. Stop - **do not terminate** - the instance to be restored to.
2. Detach the EBSes(es) that will be replaced.
3. Attach the recovery-EBS(es) in place of the previously-detached EBS(es).
4. Restart the instance
5. Verify that instance starts as expected with the restore EBS(es) in place and verify restore EBS(es) data is in the expected state

This procedure assumes that the recovery-script was used to build the recovery EBS(es) in the same availability-zone as the instance to be restored to.
### Parallel-Restore

## File-Level Restore
