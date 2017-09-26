Create an image based on hLinux. We default to unstable but DIB_RELEASE
is mapped to any series of Debian.

Use of this element will also require the tool 'debootstrap' to be
available on your system. It should be available on Ubuntu, Debian,
and Fedora.

Optional configuration:

- `DIB_DEBIAN_INITIAL_PACKAGES`: the initial set of packages installed
   by debootstrap.

- `DIB_DEBIAN_KEYRING`: the location of an apt-key keyring file for
   debootstrap to use to check the Release files.

- `DIB_DEBIAN_DEBOOTSTRAP_SCRIPT`: the location of the debootstrap
   script.

The `DIB_OFFLINE` or more specific `DIB_DEBIAN_USE_CACHED_IMAGE` variables
can be set to prefer the use of a pre-cached root filesystem tarball.

This follows, but simplifies, the debian element from diskimage-builder.
We'll expect to move back to that in the future.
