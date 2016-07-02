# jaks - Just Another Kickstart Script

Facilitates automation of RHEL/Fedora/CentOS installations

```text
        ____.  _____   ____  __.  _________
        |    | /  _  \ |    |/ _| /   _____/
        |    |/  /_\  \|      <   \_____  \
    /\__|    /    |    \    |  \  /        \
    \________\____|__  /____|__ \/_______  /
                     \/        \/        \/
          Just Another Kickstart Script
```

## Cloning ##
This project includes a set of customizable `%post` configuraton tools
to assist in both hardening and customizing the system once installed.

Because of this it is best to clone the project with the `--recursive`
option. Please see the `INSTALL` document for additional details.

## Options ##
The options listed below are custom arguments which supercede those provided
from the [installer](https://rhinstaller.github.io/anaconda/boot-options.html).

### General ###
`INSTALL` *[(boolean) Default: false]* -
Disables safety prompt and can facilitate an automated installation.

`DEBUG` *[(boolean) Default: false]* -
When set to 'true' forces user input & generates informational reports based
on the following;

 1. Provided boot arguments
 2. Root user account details
 3. Locale/Timezone specific information
 4. Networking specific information
 5. Disk(s) configuration

`ROOTPW` *[(string) Default: (empty)]* -
Here a root user account can be configured to asssit with automation.

### Locale/Timezone ###
`LOCATION` *[(string) Default: (empty)]* -
The location can be used to supercede the GeoIP installation option.

### Networking ###
`IP` *[(string) Default: (empty)]* -
If specified, this option will set the default IP address of the system
and will superceede the default `ip` option when both are provided. This
allows for a possible temporary build environment network configuration.

`NETMASK` *[(string) Default: (empty)]* -
If specified, this option will set the default subnet of the system
and will superceede the default `netmask` option when both are provided.

`GATEWAY` *[(string) Default: (empty)]* -
If specified, this option will set the default route of the system
and will superceede the default `gateway` option when both are provided.

## Disk(s) configuration ##
The `JAKS` LVM disk configuration is based on a configurable template
variable. It will detect all non-usb & non-network storage devices and
assemble them into the following partition schema.

```text
Physical partition(s)
  /boot
  /boot/efi (when an EFI installation is used)

LVM configuration
  swap
  /
  /var
  /export/home
  /tmp
  /opt/app
```  

The current decision tree that auto-assembles the disks is shown here and
will vary based on the number of block devices & the size of each block device.

All sizes are represented in bytes
```text
d^n = Physical disks 
m = Physical System Memory
b = 524288000 (500MB)
f = 107374182400 (100GB)
pp = 107374182400 + 42949672960 + 10737418240 + 2147483648 (Physical Partitions)
vp = 42949672960 + 21474836480 + 10737418240 + 2147483648 (Virtual Partition)
op = .40 + .20 + .10 + .2 (Less than 100GB in size. Allocates by percentages of disk size)

	(d^n = 1) ? d0 – (b + m x 1) –
        (d0 > f) && (d0 < pp) ? d0 – (pp + d0 (.75))
        (d0 = f) && (d0 > pp) ? d0 – (vp + d0(.75))
        (d0 < f) ? d0 – (op + d0(.75))
	(d^n > 1) ? d0 – (b + m x 1) – (pp + d^n - d0(.75))
```

## Contributing ##
Contributions are welcome & appreciated. Refer to the
[contributing document](https://github.com/jas-/jaks/blob/master/CONTRIBUTING.md)
to help facilitate pull requests.

## License ##
This software is licensed under the
[MIT License](https://github.com/jas-/jaks/blob/master/LICENSE).

Copyright Jason Gerfen, 2015-2016.
