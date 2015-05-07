# Functionality
The this script accepts the name of an snapshot "`Name`" attribute and then performs the following actions:

1. Creates EBS(es) from volume snapshots matching the passed "`Name`" attribute. The EBS(es) will be created within the same AWS availability zone (AZ) as the host invoking the script.
2. Computes a list of free attachment points. This script will determine which of the volume attachment-points (per current AWS limitations, `/dev/sdf` through `/dev/sdz`) are currently occupied, then construct a list of the unused volume attachment-points.
3. Using the free-slot list generated in the prior list, attach the newly-created EBS(es) to the invoking Linux-based instance. Free slots are attached to from lowest to highest, starting from `/dev/sdf` - or the lowest available slot - until all slots are exhausted. If there are more elements in a consistency-group than there are available free slots, the script will abort.
4. [FUTURE CAPABILITY] Once the target EBSes are attached to the instance, the script will attempt to import any LVM2 volume groups found on the EBSes.


# Assumptions/Requirements
This script assumes that all of the elements of a consistency group share a common "`Snapshot Group`" attribute. While it is expected that the "`Snapshot Group`" attribute's value will be of the form:

&nbsp;&nbsp;&nbsp;YYYYMMDDHHMM (&lt;INSTANCE_ID&gt;)

It is not, however, a hard requirement. This expectation is simply derived from the "`Name`" attribute set by this script's associated backup script(s). Any "`Name`" value will do, so long as:
- All members of an EBS consistency-group share a common "`Name`" attribute.
- All "`Name`" attributes are unique across EBS-groups within an AWS region

# Usage
To use this script, invoke in a manner similar to:

&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)"`
or
&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)" -t gp2`
or
&nbsp;&nbsp;&nbsp;`RestoreByName.sh -g "201505071621 (i-2dfc97db)" -t io1 -i 600`

The quotations shown above are only required if using "`Snapshot Group`" attributes that contain spaces or other characters that may break shell-globbing.
