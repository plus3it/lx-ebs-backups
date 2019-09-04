## Bulk Snapshot-Expiry Tools

The following are meant to facilitate performing "bulk" deletion of previously-created EBS snapshots. Intended use case is for expiring bulk-created snapshots, however, the functions' parameters allow a somewhat broader usage:

* The tools require that an expiry age (in days) be supplied
* The tools further accept a customized search-key (default value is `BackupName`) and associated search-value (default value is `Bulk Backup`). This allows more-explicit targeting of previous creation-operations' snapshots.

Any EBS snapshot that was created the specified number of days previously (or earlier) and that match the search-key and search-value will be found and deleted.

**The expiry-related files:**

* `BulkExpire.py`: Python script meant for either interactive use from an administration host or a within EC2/ECS scheduled-task.
* `BulkExpire_lambda.py`:  A Lambda-enabled version of the `BulkExpire.py` Python script. Expected to be invoked via a CloudWatch Rules scheduled-action. The function expects the invoking-service to pass "event" data to the function. The function will look for a JSON input-constant of the form:

    ~~~
    { "ExpireDays": "<NUM_DAYS>", "SearchKey": "<TAG_NAME>", "SearchVal": "<TAG_VALUE>" }`.
    ~~~

    These will be mapped to the relevant search criteria that the function will use to perform bulk-deletion of EBS snapshots. As noted prviously, the `"SearchKey"` and `"SearchVal"` are optional and may be omitted &ndash; meaning the JSON input-constant may be as simple as:

    ~~~
    { "ExpireDays": "<NUM_DAYS>" }
    ~~~

* `BulkExpire_IAM.template.json`: A simple CloudFormation template to set up the requisite IAM role to provide the bare-minimum permisions for the Lambda function to operate.
* `BulkSnapOrExpire_function.tmplt.json`: A simple CloudFormation template to set up the Lambda function to perform backup-expiry tasks.
* `BulkExpire-CWrule.tmplt.json`: A simple CloudFormation template to set up the CloudWatch event-rule to trigger the backup-expiry Lambda function on a regular basis.
* `BulkExpire-parent.tmplt.json`: A parent template that wraps all the prior templates as children in a singly-deployable stack-set.
