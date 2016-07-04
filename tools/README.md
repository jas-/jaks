# jaks2iso - Assists with building an ISO image
The `jaks2iso` tool accompanying this project facilitates customizing any
`Anaconda` based [distribution](http://fedoraproject.org/wiki/Anaconda/Distros).

It requires the following binaries; `mkisofs` & `isohybrid`.

## jaks-post-config; OS hardening & customization tool(s) ##
While optional; the [jaks-post-config](https://github.com/jas-/jaks-post-config)
toolkit assists in every facet of configuring the system in the pre-boot
(chroot) environment.

It is exendable and provides a wide range of `%post` configuration
tools for things like [network](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-network),
[DNS](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-dns),
[login defaults](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-acct-defaults),
[auditing](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-audit-rules),
[PAM](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-pam-cracklib),
[services](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-services-disable) &
[user account creation](https://github.com/jas-/jaks-post-config/blob/master/scripts/config-user-admin).

This tool is currently configured as a sub-module of this repository making it
easy to include it as a dependency when cloned with the `--recursive` option.

## Contributing ##
Contributions are welcome & appreciated. Refer to the
[contributing document](https://github.com/jas-/jaks/blob/master/CONTRIBUTING.md)
to help facilitate pull requests.

## License ##
This software is licensed under the
[MIT License](https://github.com/jas-/jaks/blob/master/LICENSE).

Copyright Jason Gerfen, 2015-2016.
