proliant-tools
==============

* This element can be used when building ironic-agent ramdisk.  It
  enables ironic-agent ramdisk to do in-band cleaning operations specific
  to HP ProLiant hardware.

* Works with hlinux distributions (on which ironic-agent
  element is supported).

* Currently the following utilities are installed:

  + `proliantutils`_ - This module registers an ironic-python-agent hardware
    manager for HP ProLiant hardware, which implements in-band cleaning
    steps.  The latest version of ``proliantutils`` available is
    installed.  This python module is released with Apache license.

  + `HP Smart Storage Administrator (HP SSA) CLI for Linux 64-bit`_ - This
    utility is used by ``proliantutils`` library above for doing in-band RAID
    configuration on HP ProLiant hardware.  Currently installed version is
    2.10. This utility is closed source and is released with
    `HP End User License Agreement – Enterprise Version`_.

.. _`proliantutils`: https://pypi.python.org/pypi/proliantutils
.. _`HP End User License Agreement – Enterprise Version`: ftp://ftp.hp.com/pub/softlib2/software1/doc/p2057331991/v33194/hpeula-en.html
