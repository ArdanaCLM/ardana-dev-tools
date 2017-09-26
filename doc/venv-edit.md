
(c) Copyright 2015 Hewlett Packard Enterprise Development LP
(c) Copyright 2017 SUSE LLC

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.


# Third-party driver support

This document provides an overview of deployer-side additions to an Ardana
deployment.


## Deployer-side venv editing

Additional driver code may be required in a venv: this Python driver code can
be injected into a venv using the venv-edit.yml playbook.


### As a customer

The third-party driver contains a directory of packaged Python content
(wheels). This can be injected into a venv as follows. Assume that the
wheelhouse is unpacked in `/home/ardanauser/third-party-wheelhouse` and
it's to be applied to the nova venv.

    cd ~/openstack/ardana/ansible
    ansible-playbook -i hosts/localhost venv-edit.yml \
        -e source=/opt/ardana_packager/nova-20150101T120000Z.tgz \
        -e suffix=001 \
        -e wheelhouse=/home/ardanauser/third-party-wheelhouse \
        -e wheel='foo-driver'

The result of this will be to create a second venv,
`nova-20150101T120000Z001.tgz` in the `/opt/ardana_packager` directory, and
update the `packages` manifest in that directory to record it.

At this point a deployment (or an upgrade) can take place as normal. Because
the deployer considers the new version number (`20150101T120000Z001`) to be in
advance, that venv package will be selected. For the case of an upgrade,
service restarts will be performed as necessary.


#### Patching a venv after a deploy has already occurred

Typically it would be advisable for a customer to patch their venvs prior to a
deploy or upgrade: indeed, one would expect that in most scenarios, the need
for a partcular extra driver will be understood in advance.

It is not, however, a hard-and-fast requirement to do this. Because the
venv-edit process produces a new venv with an updated version number, the
driver can be inserted after an initial deployment - and the typical upgrade
process will replace the running venvs with the newer one.


#### Handling multiple drivers

It is possible to apply several third-party patches at once, either
one-at-a-time (with suffixes 001, 002, etc.) or potentially all-at-once. To do
this, the contents of the input wheelhouses should be combined, and the target
wheel names be given, space-separated, as the `wheel` parameter to
`venv-edit.yml`.

    mkdir ~/third-party-wheelhouse
    cp ~/third-party-wheelhouse-{foo,bar,baz}/* ~/third-party-wheelhouse
    ansible-playbook -i hosts/localhost venv-edit.yml \
        -e source=/opt/ardana_packager/nova-20150101T120000Z.tgz \
        -e suffix=001 \
        -e wheelhouse=/home/ardanauser/third-party-wheelhouse \
        -e wheel='foo-driver bar-driver baz-driver'

Whether or not this is advisable is a decision that depends upon context: for
instance, it might be the case that multiple additional drivers can be
configured to live side-by-side in the storage case; depending on the
invasiveness of the driver, however, it's likely that it only makes sense to
have one third party driver - eg, for neutron.


#### Rolling third-party drivers forward with new Ardana versions

There is no automatic support for this; driver patches must be reapplied to
their target venvs every time a new Ardana Openstack version is received.


### As a driver packager

The requirement for the packager is to construct a 'wheelhouse' directory.
Wheels are a standard Python distribution format. They can be constructed
using the 'wheel' command. Typically the process might look as follows: it is
not necessary that this process be performed on the deployer itself; such
packaging could potentially be performed in advance, merely delivering the
finished wheelhouse to the customer.

Note that binary contents (Python .so files) will need to be compatible with
the version of Python in the target venv.

    # Assumes the source is in ~/scratch/source_dir
    virtualenv ~/scratch/v
    mkdir ~/third-party-wheelhouse
    ~/scratch/v/bin/pip install -U pip wheel
    ~/scratch/v/bin/pip wheel --wheel-dir ~/third-party-wheelhouse ~/scratch/source_dir

At the end of this process, a number of wheels will be left in `~/third-party-wheelhouse`.
These may include additional dependencies specified through the usual distutils
machinery.


#### Binary dependencies: in-venv

Providing that the wheelhouse is constructed on a system that's
binary-compatible with the target venv (and therefore the host that it'll be
deployed on), native extensions can be packaged as wheels without any
additional effort.

A compiler toolchain will be required to make this work.


#### Binary dependencies: at the OS layer

Some Python drivers utilise third-party binary extensions that are installed
into the base operating system; Ceph's `rados.py` is an example of this. For
those third-party drivers, the install playbook will need to be extended to
ensure that the additional third-party libraries are installed on the
appropriate target systems.


#### Packaging non-pypi-based Python

In some cases it's necessary to generate a wheel out of Python code that has
not been suitably packaged (a missing setup.py, perhaps, or no pypi versions
available).

Whilst the generation of a wheel from first principles is beyond the scope of
this document, the format itself is pretty trivial: see
[PEP 0427](https://www.python.org/dev/peps/pep-0427/) for details. A
rudimentary - but sufficient - implementation of this can be seen in the
[wheels_parallel script](../ansible/roles/venv/templates/wheels_parallel.bash.j2).


## Additional third-party deb packages

(TODO)

## Additional install/configure/start/stop hooks

(TODO)

