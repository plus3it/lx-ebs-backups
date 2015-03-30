The scripts in this collection are designed to make use of either instance permissions or to leverage an AWS IAM user or role. If using an AWS IAM user or role, the following minimum permissions-set is required:

- Effect:
  - Allow
- Actions:
  - ec2:CreateSnapshot
  - ec2:CreateTags
  - ec2:DeleteSnapshot
  - ec2:DescribeInstanceAttribute
  - ec2:DescribeInstanceStatus
  - ec2:DescribeInstances
  - ec2:DescribeSnapshotAttribute
  - ec2:DescribeSnapshots
  - ec2:DescribeVolumeAttribute
  - ec2:DescribeVolumeStatus
  - ec2:DescribeVolumes
  - ec2:ReportInstanceStatus
  - ec2:ResetSnapshotAttribute
- Resource:
  - "*"

Note: while the above role-permissions will allow the AWS-actions to function even when run from an un-privileged local account, privileged access will be required to enable to run privileged OS-level commands (e.g., `fsfreeze`)
