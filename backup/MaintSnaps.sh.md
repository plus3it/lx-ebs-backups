The purpose of this script is to find all backups associated with the calling-instance's instance-ID with the intent of expiring any images that are older than the threshold date. The threshold date is set in the "`commonVars.env`" file's `DEFRETAIN` variable. This script will:
1. Pull the calling-instance's instance-ID from its instance meta-data URL
2. Search for Snapshots that were previously generated for the calling-instance (by the backup scripts found elsewhere in this tool-set).
3. Determine which of the instance's automatically generated snapshots are older than the threshold date.
4. Delete all of the calling-instance's snapshots that are older than the threshold date
