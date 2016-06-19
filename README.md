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

## Options ##
The options listed below are custom arguments which supercede those provided
from the [installer](https://rhinstaller.github.io/anaconda/boot-options.html).

### General ###
`INSTALL` [(boolean) Default: false]
Disables safety prompt and can facilitate an automated installation.

`DEBUG` [(boolean) Default: false]
When set to 'true' forces user input & generates informational reports based
on the following;

 1. Provided boot arguments
 2. Root user account details
 3. Locale/Timezone specific information
 4. Networking specific information
 5. Disk(s) configuration

`ROOTPW` [(string) Default: (empty)]
Here a root user account can be configured to asssit with automation.

### Locale/Timezone ###
`LOCATION` [(string) Default: (empty)]
The location can be used to supercede the GeoIP installation option.

### Networking ###



## contributing ##
Contributions are welcome & appreciated. Refer to the
[contributing document](https://github.com/jas-/jaks/blob/master/CONTRIBUTING.md)
to help facilitate pull requests.

## license ##
This software is licensed under the
[MIT License](https://github.com/jas-/jaks/blob/master/LICENSE).

Copyright Jason Gerfen, 2015-2016.