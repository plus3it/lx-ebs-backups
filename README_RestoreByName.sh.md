# Functionality
This script is designed to create EBS volumes from snapshots previously created using the `SnapByCgroup.sh` script. This script takes several arguments:

- **Snapshot Group**: This argument is *mandatory*. A "snapshot group" is group of one or more snapshots created by the `SnapByCgroup.sh` script. This argument is prepended with either the `-g` or `--snapgrp` commandline switch.
- **Availability Zone**: This argument is optional. If this argument is not given, the restored EBS volumes will be created within the same AZ as the instance the script is executed from. This argument is prepended with either the `-a` or `--az` commandline switch. Legal values are any availability zones in the same region as the instance the script is run from.
- **EBS Type**: This argument is optional. If this argument is not given, the restored EBS volumes will be created as (standard) magnetic volumes. This argument is prepended with either the `-t` or `--ebstype` commandline switch. Legal values are `standard`, `gp2` and `io1`
- **Provisioned IOPs**: This argument is mandatory if the **EBS TYPE** has been selected as `io1`. This argument is prepended with either the `-i` or `--iops` commandline switch. Valid values are restricted to integers and will depend on the size of the volume(s) being restored.

Assuming all mandatory arguments and valid optional arguments have been specified, this script will then create EBS(es) from volume snapshots matching the passed "`Snapshot Group`" attribute. The restored EBS(es) will be standard magnetic volumes unless the **EBS Type** option has been specified and will be created in the invoking host's availability zone unless the **Availability Zone** option has been specified.

# Assumptions/Requirements
## AWS Permissions
The permissions specified in the [permissions README](README_AWSpermissions.md) are the aggregated permissions-set required to allow *all* of the scripts in this project to function. If your operating environment splits resposibilies for snapshot-setup and snapshot-restore operations, it is likely that you will have delegated different permissiosn sets to the groups responsible for each of those tasks. To do a restore, an administrator will need *all* of the permissions defined in the permissions README.
## Tagging/Labeling
This script assumes that all of the elements of a consistency group share a common "`Snapshot Group`" attribute. While it is expected that the "`Snapshot Group`" attribute's value will be of the form:

&nbsp;&nbsp;&nbsp;YYYYMMDDHHMM (&lt;INSTANCE_ID&gt;)

It is not, however, a hard requirement. This expectation is simply derived from the "`Snapshot Group`" attribute set by this script's associated backup script(s). Any "`Snapshot Group`" value will do, so long as:
- All members of an EBS consistency-group share a common "`Snapshot Group`" attribute.
- All "`Snapshot Group`" attributes are unique across snapshot-groups within an AWS region

## Instance Configuration Items
If performing a full-recovery restore-scenario, it is possible that centalized authentication functions may not be functional. If centralized authentication isn't functioning, it will be critical that the snapshot source-instance have been configured to allow logins from a local "maintenance" account.

It is generally assumed that SSH key-based logins will be used for this. However, if key-based logins are explicitly disabled within - or the launch-key's password is unkown - it will be necessary to do password-based login to the "maintenance" account. In either key-based or password-based login scenarios, the recovery-administrator will need to know the password necesary to provide access.

Note: Depending on the presence of the cloud-init package and its subsequent configuration within the backed-up instance, a usable, key-based maintenance account will be created when the recovered instance starts from the recovery-EBSes.

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
"Bare-metal" restores are understood to mean any restore scenario where an entire production system's EBS's contents are wholly replaced from a backup copy. A "bare-metal" style restore can be done in two main ways: restore-in-place and parallel-restore.
### Restore-In-Place
In this scenario, the recovery volumes are recovered to the original, presumably broken instance. Steps for doing so are as follows:

1. Stop - **do not terminate** - the instance to be restored to.
2. Detach the EBSes(es) that will be replaced.
3. Attach the recovery-EBS(es) in place of the previously-detached EBS(es).
4. Restart the instance
5. Verify that instance starts as expected with the restore EBS(es) in place and verify restore EBS(es) data is in the expected state

This procedure assumes that the recovery-script was used to build the recovery EBS(es) in the same availability-zone as the instance to be restored to.
### Parallel-Restore
In this scenario, the recovery volumes are recovered to a new instance. It is assumed that both the root EBS(es) and application-data EBS(es) will be restored. Steps for doing so are as follows:

1. Launch a new instance into the same availability-zone that the EBS-recovery was performed to.
  - If the AMI used for the original instance is still available, use the "Launch More Like This" option from the AWS console to launch the replacement-instance
  - If the AMI used for the original instance is no longer available, launch a new, equivalent instance - ensuring to set all of the requisite IAM, security group, VPC options, etc. that were applied to the original instance. Do not attach any additional disks to the new instance as they will be discarded.
2. After the new instance has complete launching (2 of 2 launch tests have succeeded), stop - **do not terminate** - the new instance.
3. After the new instance has stopped, detach all EBS volumes currently attached to the instance.
4. Discard the detached EBS volumes.
5. Attach the EBS recovery volumes to their appropriate locations (e.g., if an EBS was built from a snapshot of an EBS attached at /dev/sda1, attach the recovery EBS at /dev/sda1 of the new instance)
6. If the original instance is still in a running state, power it down (**do not terminate it**). This is a safety-measure to ensure that things like Active Directory bindings do not create conflicts.
7. If the original instance had EIPs (etc.) associated to it, re-associate those objects to the replacement instance.
8. Power on the replacement instance (with the recovery EBSes attached)
9. Verify that the replacement instance starts up (2 of 2 launch tests have succeeded)
10. Login to the instance and verify functionality.
11. Ensure that any external services dependent on the original instance are functioning correctly with the recovery instance.

## File-Level Restore
