The scripts in this collection are designed to make use of either instance permissions or to leverage an AWS IAM user or role. If using an AWS IAM user or role, the following minimum permissions-set is required:

- Effect:
  - Allow
- Actions:
  - ec2:CopySnapshot
  - ec2:CreateSnapshot
  - ec2:CreateTags
  - ec2:CreateVolume
  - ec2:DeleteSnapshot
  - ec2:DeleteTags
  - ec2:DeleteVolume
  - ec2:DescribeInstanceAttribute
  - ec2:DescribeInstanceStatus
  - ec2:DescribeInstances
  - ec2:DescribeRegions
  - ec2:DescribeSnapshotAttribute
  - ec2:DescribeSnapshots
  - ec2:DescribeTags
  - ec2:DescribeVolumeAttribute
  - ec2:DescribeVolumeStatus
  - ec2:DescribeVolumes
  - ec2:DetachVolume
  - ec2:ModifySnapshotAttribute
  - ec2:ModifyVolumeAttribute
  - ec2:ReportInstanceStatus
  - ec2:ResetInstanceAttribute
  - ec2:ResetSnapshotAttribute
- Resource:
  - "*"

This will create an IAM policy similar to the following
~~~
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1428510216936",
      "Action": [
        "ec2:CopySnapshot",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeInstanceAttribute",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeSnapshotAttribute",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumeAttribute",
        "ec2:DescribeVolumeStatus",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:ModifySnapshotAttribute",
        "ec2:ModifyVolumeAttribute",
        "ec2:ReportInstanceStatus",
        "ec2:ResetInstanceAttribute",
        "ec2:ResetSnapshotAttribute"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
~~~

Note: while the above role-permissions will allow the AWS-actions to function even when run from an un-privileged local account, privileged access will be required to enable to run privileged OS-level commands (e.g., `fsfreeze`)
