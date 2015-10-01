The `GetMyDisks.sh` tool is designed to help the administrator map the disk devices seen within the instance-OS to the source EBS volumes. The command takes no arguments.

~~~
$ ./GetMyDisks.sh
Root-dev should be /dev/xvda
Size (GiB)      EBS Volume-ID   Volume-Type     Block-Device
         4      vol-69b6bb90    standard        /dev/xvdh
         4      vol-34b6bbcd    standard        /dev/xvdi
         4      vol-16b6bbef    standard        /dev/xvdg
         4      vol-09b6bbf0    standard        /dev/xvdf
        20      vol-d1989728    standard        /dev/xvda
~~~

Note<sup>1</sup>: The example above does not show a root user's `#` prompt. This command will succeed regardless of the OS user's permissions, so long as the user has acquired the necessary AWS command-permissions (via instance-role, ephemeral permission-token, etc.)
Note<sup>2</sup>: When using an EL-6 based system, the mappings returned may be incorrect. The default behavior of the xen_blkfront driver in EL-6 will cause all /dev/sd devices to be seen by the OS offset from /dev/sde. This offset may be prevented by setting the parameter-value `xen_blkfront.sda_is_xvda=1` in the GRUB config's `kernel` line.
