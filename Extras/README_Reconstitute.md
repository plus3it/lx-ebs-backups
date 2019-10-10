## The Basics

The `Reconstitute.py` utility is a tool designed to automate the recovery from snapshots created by this project's other tooling. Further, this utility can automate the recovery created by other projects' tooling, so long as those snapshots contain tags that:

* The instance-ID of the EC2 that owned the EBS from which the snapshot was created
* The device-name that the EBS from which the snapshot was created was attached as
* A searchable-value that uniquely identifies a group of reconstitutable snapshots (i.e., if the backup tooling creates scheduled backups of one or more instances, the tag contains sufficient information to locate a particular EC2's snapshots created at a specific point in time)

The `Reconstitute.py` utility accepts the following arguments:

* `-h` or `--help`: Shows information about available flags and associated arguments. Specifying this flag causes the script to immediately exit after printing the help-contents &mdash; whether or not other flags and arguments are specified.
* `-a` or ` --recovery-ami`: Requires a valid AMI ID as argument. This script can automatically recover both Linux- and Windows-based EC2s. It is expected that the supplied AMI ID will be either same as the one used to create the source EC2 or in the same AMI-family (e.g. [spel](https://github.com/plus3it/spel) AMIs). It's possible that other AMIs will suffice, but such has not been tested.
* `-e` or `--ebs-type`: Requires a valid EBS-type as argument. The specified type is used during the process of reconstituting target snapshots as EBS volumes. Valid values are:
    * `standard`: Legacy "magnetic" volumes. [**NOT CURRENTLY SUPPORTED**]
    * `io1`: Provisioned IOPS SSD
    * `gp2`: Basic 'SSD' volume-type. (Default: leave flag unspecified if using this value)
    * `sc1`: "Cold" HDD (See: AWS [blog entry](https://aws.amazon.com/blogs/aws/amazon-ebs-update-new-cold-storage-and-throughput-options/)) [**NOT CURRENTLY SUPPORTED**]
    * `st1`: Throughput-optimized HDD [**NOT CURRENTLY SUPPORTED**]
* `-i` or `--iops-ratio`: Specify IOPs-ratio to use when reconstituting to `io1` EBS volumes (min:3; max: 50). Ignored if other volume-type is requested
* `-k` or `--provisioning-key`: SSH key to inject into recovery-instance [**NOT YET IMPLEMENTED**]
* `-P` or `--power-on`: Power on the recovered instance (Boolean: specify to enable end-of-recovery power-on; leave unspecified if ecovery-instance should remain powerd off)
* `-n` or `--recovery-hostname`: AWS-level name to assign to recovery-instance (as shown in EC2 console/CLI: does not effect recovered instance's internal hostname value)
* `-r` or `--root-snapid:  Snapshot-ID of original instance's root EBS (if not part of snapshot-group) [**NOT YET IMPLEMENTED**]
* `-S` or `--search-string`: String-value used to select targeted snapshots
* `-s` or `--deployment-subnet`: Subnet ID to deploy recovery-instance into
* `-t` or `--instance-type`: Instance-type to use for recovery-instance (Default: t3.large)
* `-U` or `--user-data-file`:  Inject userData from selected file
* `-u` or `--user-data-clone`: Attempt to clone userData from source instance (Boolean: specify to enable userData-cloning)
* `-x` or `--access-groups`: Security-group to assign to recovery-instance
* `--alt-search-tag`: Snapshot-attribute used to find grouped-snapshots (Default: 'Snapshot Group')
* `--alt-ec2-tag`: Snapshot-attribute containing original EC2 ID (Default: 'Original Instance')
* `--alt-device-tag`: Snapshot-attribute containing original EBS attachment- info (Default: 'Original Attachment')

Note: The `-U`/`--user-data-file` and `-u`/`--user-data-clone` options are mutually-exclusive.

## Dependencies

* This utilty is written for Python3 - and specifically tested with python 3.6. This utility does not function properly under Python 2.x
* This utility requires the following Python modules:
    * [`boto3`](https://pypi.org/project/boto3/): Boto3 is the Amazon Web Services (AWS) Software Development Kit (SDK) for Python, which allows Python developers to write software that makes use of services like Amazon S3 and Amazon EC2.
    * [`sys`](https://docs.python.org/3/library/sys.html): Provides access to some variables used or maintained by the interpreter and to functions that interact strongly with the interpreter.
    * [`time`](https://docs.python.org/3/library/time.html): Provides various time-related functions. 
    * `optparse`: Parser for command line options

## Caveats

* Script does not implement any internal/stand-alone session-management. The invoking environment will need to be configured to provide session-access to the AWS APIs as well as selection of target region.
* Script does not currently implement much in the way of validity checking for AWS-level objects (e.g., no pre-verification of AMI IDs, subnets, etc.)
* Script does not attempt to inject any provisioning (rescue) SSH public-keys into the recovery instance:
    * If the source instance relied on SSH key for login, only the keys already present in the EBS snapshots will be present in the recovered instance.
    * If the source instance relied on Kerberized authentication mechanisms (e.g. Active Directory) for login-managment, recovered instances will only be reachable if the Kerberos authentication elements stored in the source snapshots have not expired
    * If the source instance was not quiesced prior to snapshotting, the filesystems residing on the reconstituted EBS volumes will be in a "[crash consistent](https://www.trilio.io/resources/application-consistent-vs-crash-consistent-backup/)" state:
        * Recovered Linux instances should return filesystems to a clean state via filesystem log-recovery
        * Recovered Windows instances will typically display a "Shutdown Event Tracker" popup on first login.
        * Hosted applications may require application-specific recovery-methods be performed
* If the script is used to clone or "move" a live EC2 instance and the source-instance is a member a service-domain (like Kerberos/Active Directory or some kind of clustered application), it may cause collisions if the recovery-instance is powered on while the source-instance is also powered on.
* EC2s that are built with the `cloud-init` service enabled may re-run any `per-instance` automation present in the reconstituted EBSes:
    * Hostnames may be altered due to that content
    * Other launch-time automation (e.g., EC2 userData) may be triggered
