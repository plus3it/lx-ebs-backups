## Bulk Snapshot Tools

The following are meant to facilitate performing "bulk" EBS snapshot operations. Simply, all that has to be done is apply an arbitrary tag to one or more EC2 instances in an account. The context-appropriate execution of the `.py` files will then back up any EC2s with the arbitrary tag applied:

* `BulkSnap.py`: Python script meant for either interactive use from an administration host or a within EC2/ECS scheduled-task. Invoking the script with `--instance-tag <BACKUP_TAG_NAME>` will cause the script to include any EC2 with the `<BACKUP_TAG_NAME>` in the requested bulk-backup operation.
* `BulkSnap_lambda.py`: A Lambda-enabled version of the `BulkSnap.py` Python script. Expected to be invoked via a CloudWatch Rules scheduled-action. The function expects the invoking-service to pass "event" data to the function. The function will look for  JSON input-constant of the form ` { "SearchTag": <TAG_NAME> }`. Any EC2s tagged with `<TAG_NAME>` bill be included in the scheduled bulk-backup operation.
* `BulkSnap_IAM.template.json`: A simple CloudFormation template to set up the requisite IAM role to provide the bare-minimum permisions for the Lambda function to operate.
