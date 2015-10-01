This command allows the administrator to apply tags to EBS volumes even when the EC2-layer's volume-IDs are not (readily) known by the administrator. This command takes two arguments:

* Argument 1: The text-string to be applied as the "Consistency Group" value for the disk.
* Argument 2: The name of the block-device seen by the OS.

The script will evaluate the arguments passed. If the administrator fails to pass a valid block-device name, the script will abort. If a valid block-device and EBS label are supplied, the script will attempt to map the local device to its EBS volume, thn apply the supplied label to the EBS volume.

Note: The default behavior of the xen_blkfront driver in EL-6 will cause all /dev/sd devices to be seen by the OS offset from /dev/sde. This offset may be prevented by setting the parameter-value `xen_blkfront.sda_is_xvda=1` in the GRUB config's `kernel` line. If the offset is not defeated, the mappings returned may be incorrect. This will likely result in the script either failing or applying the tag to the wrong EBS volume.

