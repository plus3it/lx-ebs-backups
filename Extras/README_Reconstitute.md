## The basics

The `Reconstitute.py` utility is a tool designed to automate the recovery from snapshots created by this project's other tooling. Further, this utility can automate the recovery created by other projects' tooling, so long as those snapshots contain tags that:

* The instance-ID of the EC2 that owned the EBS from which the snapshot was created
* The device-name that the EBS from which the snapshot was created was attached as
* A searchable-value that uniquely identifies a group of reconstitutable snapshots (i.e., if the backup tooling creates scheduled backups of one or more instances, the tag contains sufficient information to locate a particular EC2's snapshots created at a specific point in time)

The `Reconstitute.py` utility accepts the following arguments:

* `-h` or `--help`: Shows information about available flags and associated arguments. Specifying this flag causes the script to immediately exit after printing the help-contents &mdash; whether or not other flags and arguments are specified.
* `-a` or ` --recovery-ami`: Requires a valid AMI ID as argument. This script can automatically recover both Linux- and Windows-based EC2s. It is expected that the supplied AMI ID will be either same as the one used to create the source EC2 or in the same AMI-family (e.g. [spel](https://github.com/plus3it/spel) AMIs). It's possible that other AMIs will suffice, but such has not been tested.
* `-e` or `--ebs-type`: Requires a valid EBS-type as argument. The specified type is used during the process of reconstituting target snapshots as EBS volumes. Valid values are:
    * `standard`: Legacy "magnetic" volumes.
    * `io1`: Provisioned IOPS SSD [**NOT YET SUPPORTED**]
    * `gp2`: Basic 'SSD' volume-type. (Default: leave flag unspecified if using this value)
    * `sc1`: "Cold" HDD (See: AWS [blog entry](https://aws.amazon.com/blogs/aws/amazon-ebs-update-new-cold-storage-and-throughput-options/))
    * `st1`: Throughput-optimized HDD
* `-k` or `--provisioning-key`: SSH key to inject into recovery-instance [**NOT YET IMPLEMENTED**]
* `-P` or `--power-on`: Power on the recovered instance (Boolean: specify to enable end-of-recovery power-on; leave unspecified if ecovery-instance should remain powerd off)
* `-n` or `--recovery-hostname`: AWS-level name to assign to recovery-instance (as shown in EC2 console/CLI: does not effect recovered instance's internal hostname value)
* `-r` or `--root-snapid:  Snapshot-ID of original instance's root EBS (if not part of snapshot-group) [**NOT YET IMPLEMENTED**]
* `-S` or `--search-string`: String-value used to select targeted snapshots
* `-s` or `--deployment-subnet`: Subnet ID to deploy recovery-instance into
* `-t` or `--instance-type`: Instance-type to use for recovery-instance (Default: t3.large)
* `-x` or `--access-groups`: Security-group to assign to recovery-instance
* `-z` or `--availability-zone`: Availability zone to build recovery-instance in (defaults to value found on snapshots)
* `--alt-search-tag`: Snapshot-attribute used to find grouped-snapshots (Default: 'Snapshot Group')
* `--alt-ec2-tag`: Snapshot-attribute containing original EC2 ID (Default: 'Original Instance')
* `--alt-device-tag`: Snapshot-attribute containing original EBS attachment- info (Default: 'Original Attachment')
