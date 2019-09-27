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
* `-k PROVISIONING_KEY, --provisioning-key=PROVISIONING_KEY
                        SSH key to inject into recovery-instance [**NOT YET
                        IMPLEMENTED**]
* `-P, --power-on        Power on the recovered instance
* `-n RECOVERY_HOSTNAME, --recovery-hostname=RECOVERY_HOSTNAME
                        Name to assign to recovery-instance (as shown in EC2
                        console/CLI)
* `-r ROOT_SNAPID, --root-snapid=ROOT_SNAPID
                        Snapshot-ID of original instance's root EBS (if not
                        part of snapshot-group) [**NOT YET IMPLEMENTED**]
* `-S SEARCH_STRING, --search-string=SEARCH_STRING
                        String-value to search for (use commas to search for
                        more than one string-value)
* `-s DEPLOYMENT_SUBNET, --deployment-subnet=DEPLOYMENT_SUBNET
                        Subnet ID to deploy recovery-instance into
* `-t RECOVERY_INSTANCE_TYPE, --instance-type=RECOVERY_INSTANCE_TYPE
                        Instance-type to use for recovery-instance (Default:
                        t3.large)
* `-x RECOVERY_SG, --access-groups=RECOVERY_SG
                        Security-groups to assign to recovery-instance
* `-z AVAILABILITY_ZONE, --availability-zone=AVAILABILITY_ZONE
                        Availability zone to build recovery-instance in
                        (defaults to value found on snapshots)
* `--alt-search-tag=SEARCH_TAG
                        Snapshot-attribute used to find grouped-snapshots
                        (Default: 'Snapshot Group')
* `--alt-ec2-tag=ORIGINAL_EC2_TAG
                        Snapshot-attribute containing original EC2 ID
                        (Default: 'Original Instance')
* `--alt-device-tag=ORIGINAL_DEVICE_TAG
                        Snapshot-attribute containing original EBS attachment-
                        info (Default: 'Original Attachment')
