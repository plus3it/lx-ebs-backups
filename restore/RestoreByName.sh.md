This script assumes that all of the elements of a consistency group share a common "Name" attribute. While it is expected that the "Name" attribute's value will be of the form:

&nbsp;&nbsp;&nbsp;AutoBack (<INSTANCE_ID>) YYYY-MM-DD

It is not, however, a hard requirement. This expectation is simply derived from the "Name" attribute set by this script's associated backup script(s). Any "Name" value will do, so long as:
- All members of an EBS consistency-group share a common "Name" attribute.
- All "Name" attributes are unique across EBS-groups within an AWS region

To use this script, invoke in a manner similar to:

&nbsp;&nbsp;&nbsp;RestoreByName.sh "AutoBack (i-57e04da1) 2015-04-01"

The quotations shown above are only required if using "Name" attributes that contain spaces or other characters that may break shell-globbing.
