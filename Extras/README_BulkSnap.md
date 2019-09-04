## Bulk Snapshot Tools

The following are meant to facilitate performing "bulk" EBS snapshot operations. Simply, all that has to be done is apply an arbitrary tag to one or more EC2 instances in an account. The context-appropriate execution of the `.py` files will then back up any EC2s with the arbitrary tag applied:

* `BulkSnap.py`: Python script meant for either interactive use from an administration host or a within EC2/ECS scheduled-task. Invoking the script with `--instance-tag <BACKUP_TAG_NAME>` will cause the script to include any EC2 with the `<BACKUP_TAG_NAME>` in the requested bulk-backup operation.
* `BulkSnap_lambda.py`: A Lambda-enabled version of the `BulkSnap.py` Python script. Expected to be invoked via a CloudWatch Rules scheduled-action. The function expects the invoking-service to pass "event" data to the function. The function will look for a JSON input-constant of the form:

    ~~~
    { "SearchTag": "<BACKUP_TAG_NAME>", "CustomBackupName": "<BACKUP_TAG_VALUE>" }
    ~~~

    Note that the `"CustomBackupName"` component is optional. This is primarily provided for testing purposes but can also be used creating batched backup-sets". If this value is supplied, resultant snapshots will have the `BackupName` tag-name applied and an associated tag-value of `<BACKUP_TAG_VALUE>`. If this is not supplied, the tag-value will be set to `Bulk Backup`. Because this data-element is optional, the JSON input-constant can be as simple as:

    ~~~
    { "SearchTag": "<BACKUP_TAG_NAME>", "CustomBackupName": "<BACKUP_TAG_VALUE>" }
    ~~~

    Any EC2s tagged with `<BACKUP_TAG_NAME>` bill be included in the scheduled bulk-backup operation.
* `BulkSnap_IAM.template.json`: A simple CloudFormation template to set up the requisite IAM role to provide the bare-minimum permisions for the Lambda function to operate.
* `BulkSnapOrExpire_function.tmplt.json`: A simple CloudFormation template to set up the Lambda function to perform backup-actions.
* `BulkSnap-CWrule.tmplt.json`: A simple CloudFormation template to set up the CloudWatch event-rule to trigger the backup Lambda function on a regular basis.
* `BulkSnap-parent.tmplt.json`: A parent template that wraps all the prior templates as children in a singly-deployable stack-set.

