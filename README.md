# jaks - Just Another Kickstart Script

Facilitates automation of any `Anaconda` based
[distribution](http://fedoraproject.org/wiki/Anaconda/Distros)

```text
         ____.  _____   ____  __.  _________
        |    | /  _  \ |    |/ _| /   _____/
        |    |/  /_\  \|      <   \_____  \
    /\__|    /    |    \    |  \  /        \
    \________\____|__  /____|__ \/_______  /
                     \/        \/        \/
          Just Another Kickstart Script
```

## Options ##
The options listed below are custom arguments which supercede those provided
from the [installer](https://rhinstaller.github.io/anaconda/boot-options.html).

### General ###
The options provided here allow for configuration of the `grub` boot options.

| Option | Type | Default | Description |
|:-|:-:|:-:|:-|
| `INSTALL` | *boolean* | false | If specified will skip the safety check regarding installation |
| `DEBUG` | *boolean* | false | Used to display reports for each category of `%pre` & `%post` script execution |
| `LANG` | *string* | en_US.UTF-8 | Correlates to the language options found @ `/usr/share/system-config-language/locale-list` |
| `LOCATION` | *string* | America/Denver | Must be a valid timezone specified by the [IANA timezone database](https://www.iana.org/time-zones) |
| `ROOTPW` | *string* | NULL | If not specified will prompt user for input |


### Networking ###
While the `anaconda` API does contain [networking](https://rhinstaller.github.io/anaconda/boot-options.html#network-options), the `jaks` networking options can be used to supplement them which allows for a temporary build environment.

| Option | Type | Default | Description |
|:-|:-:|:-:|:-|
| `IP` | *string* | NULL | If specified, this option will set the default IP address of the system and will superceede the default `ip` option when both are provided. This allows for a possible temporary build environment network configuration. |
| `NETMASK` | *string* | NULL | If specified, this option will set the default subnet of the system and will superceede the default `netmask` option when both are provided. |
| `GATEWAY` | *string* | NULL | If specified, this option will set the default route of the system and will superceede the default `gateway` option when both are provided. |


### Disk(s) configuration ###
The `JAKS` LVM disk configuration is based on a configurable template
variable. It will detect all non-usb & non-network storage devices and
assemble them into the following partition schema.

| Path | Type | Size
|:-|:-:|:-|
| `/boot` | *Physical* | 500MB |
| `/boot/efi` | *Physical* | 500MB |
| `swap` | *LVM* | Physical Memory x 2 |
| `/var` | *LVM* | See [Disk sizing](markdown-header-disk-sizing) |
| `/export/home` | *LVM* | See [Disk sizing](markdown-header-disk-sizing) |
| `/tmp` | *LVM* | See [Disk sizing](markdown-header-disk-sizing) |
| `/opt/app` | *LVM* | See [Disk sizing](markdown-header-disk-sizing) |


#### Disk sizing ####
To accomodate for disks of varying size the folling conditionals are
used to determine how to assemble the disk(s).

*All sizes are represented in bytes*
```text
d^n = Physical disks
m = Physical System Memory
b = 524288000 (500MB)
f = 107374182400 (100GB)
pp = 107374182400 + 42949672960 + 10737418240 + 2147483648 (Physical Partitions)
vp = 42949672960 + 21474836480 + 10737418240 + 2147483648 (Virtual Partition)
op = .40 + .20 + .10 + .2 (Less than 100GB in size. Allocates by percentages of disk size)
```

And the decision tree that auto-assembles the disks is shown here. The final
result will depend on the size and the number of disk(s) found on the host.

```text
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

Copyright Jason Gerfen, 2015 - 2017.
