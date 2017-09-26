
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


# Design of the venv packages

The venv packages are simply a very lightweight way to deliver software
(or other filesystem contents) to resource nodes in a cluster.

Separating the build of Python venvs from their deployment at cluster
stand-up time permits the construction of a CI pipeline that can optimise
the amount of rebuilding required.

## Layout

The venv originates as a normal Python virtualenv.

### Version numbering

By default, venvs are built with a version number that's based upon the
UTC ISO8601 timestamp.

Those venvs will end up in a predictable location on the filesystem which
is derived from the venv name and its version number, for example:

    /opt/stack/venv/
                nova-20150401T100000Z/
                  bin/
                    python
                  lib/
                    python2.7/
                  ( etc ... )

### Relocation

Python virtualenvs are not normally relocatable; they contain references to
their initial path in the shebang lines of and binaries installed under `bin/`.

The `virtualenv --relocatable` command is (currently) broken; it rewrites
those shebang lines in a way that relies upon the virtualenv's `bin/` directory
appearing early on any user's path. That can't be guaranteed in all
circumstances. Instead, the `venv-build.yml` playbook contains a step which
will rewrite the shebang lines to expect installation at the above location.

These venvs are not, therefore, generally relocatable.

### Service components

In many cases, there are a number of service components which depend upon
the same underlying source code.

During an upgrade, it may be the case that one service component continues
to run with an older version of the software, whilst another service component
runs with an upgraded version.

In order to support this, several service components can refer to the same
underlying venv for their source.

Each service component gets its own versioned directory, as follows, which
contains a symlink to the underlying venv and a local directory to contain
configuration:

    /opt/stack/service/
                nova-api-20150401T100000Z/
                  venv -> /opt/stack/venv/nova-20150401T100000Z
                  etc/

When a service component is installed, a convenience symlink that does not
contain a version number is also installed to point to the concrete versioned
subdirectory:

    /opt/stack/service/
                nova-api -> nova-api-20150401T100000Z

It's therefore possible to predictably locate an executable, for example,

    /opt/stack/service/nova-api/venv/bin/nova-api

will correctly resolve. However, in order to preserve an abstraction to
future-proof service teams' playbooks, there are some J2 filters provided
for convenience of writing playbooks: see below.


## Configuration files: per service component and versioned

A service team may wish to continue to configure their service using files in
the `/etc` directory; however, this is not recommended. Rather, where possible,
the per-service-component versioned configuration directory should be
preferred. This permits the association of one version of the software with
its corresponding configuration.

Again, there are J2 filters provided for convenience here.


## The venv repo

The venv repo is a static web-server; it is supplied by an Apache instance
running on the deployer node.

The repo contents comprise a set of tarballs together with a package manifest
(at a predictable location relative to the repo URL).

The deployer bootstrapping stage includes the standup of an Apache server and
the creation of the package manifest from the contents of `/opt/ardana_packager`.


### Package manifest

The package manifest is a YAML-formatted file. The format of that manifest
file is subject to change; Ansible support for handling that manifest is
provided to isolate playbooks from change.


## Ansible support

There is ansible support for fetching and installing packaged venvs, as
follows.

The support is enabled by applying the `package-consumer` role to a node; this
is done as part of the osconfig step.


### install_package module

The install_package module abstracts the operations required to fetch and
install a pre-packaged venv, and to link it up as a service component.


#### Refresh the package cache

The following step should not be required: it is run as the final step of
the `package-consumer` role:

    - name: Refresh the package cache
      install_package: cache=update


#### Install a service component

The following step may be used by a service team to install a service component
based upon a pre-build venv.

    - name: Install the nova-api service from the nova venv
      install_package: name=nova service=nova-api state=present

Note: this step is idempotent; whilst the `install_package` module can take
a version number, by default it will install the latest version of the venv
that it knows about.

Note: unlike a dpkg package, no other code or preparation tasks are run by
this module: it solely delivers content to a filesystem. In particular, an
`install` verb may wish to create service users, to install binary
prerequisite packages (via the `apt` Ansible module), and so on.

Note: it is possible to have several service components that lean on the same
underlying source-code. In that case, the service-component directories will
all be created with `venv` symlinks that point to the same installed package.

A service component can be uninstalled by setting its state to `absent`:

     - name: Uninstall the nova-api service
       install_package: name=nova service=nova-api state=absent

This use of `state` follows the other package installation modules in ansible.
In the case where several service-components have been installed from the same
underlying version of a package, only when the last one is removed will the
shared source-code be deleted.


### bin_dir, config_dir and share_dir J2 filters

In order to assist in the registration of services, the configuration of
`rootwrap`, and so on, there are three J2 filters that can be used to
locate the binary, per-service-component configuration and 'extra files'
directories, respectively:

    - name: Run nova-manage
      command: "{{ 'nova-conductor' | bin_dir }}/nova-manage db-sync"

    - name: Install some configuration
      template:
        src: nova.conf.j2
        dest: "{{ 'nova-api' | config_dir }}/nova-api.conf"

    - name: Get extra config files
      copy:
        src: "{{ 'nova-api' | share_dir }}/nova/nova-api.ini"
        dest: "{{ 'nova-api' | config_dir }}"

Note: with the current implementation, `bin_dir`,`config_dir` and `share_dir`
return paths that utilise the unversioned service-component symlinks
described above.

Should a concrete, versioned path be required, both filters take an optional
parameter which can be used to specify a concrete version number:

    - name: Run nova-manage
      command: "{{ 'nova-conductor' | bin_dir(nova_version) }}/nova-manage db-sync"

See below for how to identify these version numbers.


### load_packages J2 filter

The `package-consumer` role may be depended upon by any other service-team
role. There is no requirement to do this (the role's applied by `osconfig` by
default).

However, it may still be desirable to depend on that role, since it uses a
J2 filter (which is evaluated on the deployer node) to load the current
package manifest into a J2 variable:

    # From the pacakge-consumer defaults/main.yml:
    packages: "{{ '/opt/ardana_packages' | load_packages() }}"


### package_max_version J2 filter

Given the above, it's possible to identify the latest version of a package
*available in the package manifest*. Because J2 filters are expanded on the
deployer, not the target node, the following identifies the version of a
package *that is available*.

It is up to the service teams' playbooks to ensure that that package is
actually installed, in order for the following filter to be useful:

    - name: Report the latest 'nova' package available in the manifest
      debug:
        msg: Latest nova package is {{ packages | package_max_version('nova') }}
        # Need to depend on package-consumer to get 'packages' registered.


### The setup_systemd module

In order to configure a systemd unit that encapsulates a venv-installed binary,
the `setup_systemd` Ansible module is provided. It is used as follows:

    - name: Register the nova-api service
      setup_systemd:
        service: nova-api
        cmd: nova-api
        name: nova-api
        user: nova_api
        group: nova
        args: --config {{ 'nova-api' | config_dir }}/nova/nova.conf

Note: The service will *not* be started; *nor* will it (currently) be registered
to start automatically (that behaviour appeared to be an antipattern in TripleO;
we consider that a reboot of a machine typically implies operational oversight.
This is a decision that needs to be reviewed with product management).

There are *three* parameters which need to be considered when registering a service:

- `service`: this is the name of the service component - it corresponds to the
  `service` parameter in the `install_package` module.

- `cmd`: this is the executable which can be found in the `bin_dir` of the
  specified service component.

- `name`: this is the *name of the systemd unit* that will be registered. For the
  simple case where a service component is associated with a *single* running
  top-level process, the value of this parameter defaults to the value given
  for the `service` parameter; under these circumstances, `name` can be
  omitted.

The additional parameters are:

- `user` and `group`: the user and group which will own the process launched by
  systemd.

- `args`: any additional arguments to pass to the daemon process.


## Further extensions

Since the venv itself is simply a tarball, there's no particular impediment
to using the same tarball delivery mechanism to deploy other items that
require versioning; for instance, it might be desirable to bundle up
Zookeeper in this fashion.

If it transpires that more fine-grained control or examination of a target node
is required, those capabilities could be added to the install_package tool.


## Making executables available to external processes

The main drawback with the approach above is that executables end up on
nonstandard paths.

Where those paths can be configured explicitly (such as by the `setup_systemd`
module), that's not a problem: and in those cases, the venvs provide some
measure of isolation.

However, there are two situations where this approach doesn't suffice.


### The service-rootwrap commands

Some service processes attempt to call out via sudo to elevate their
privileges. In nova, that invocation looks like this:

    sudo nova-rootwrap # ... rest of command here

The initial part of that line, `sudo nova-rootwrap` is not completely
configurable from `nova.conf`; therefore, an alternative method must be
used to ensure that the appropriate `nova-rootwrap` can be found.

One approach would be to explicitly configure `/etc/sudoers.d/nova` to
set a path that includes the venv.

However, a simpler approach is to ensure that references to the desired
executables appear in a directory on the standard search path.

Therefore, for the moment we recommend creating symlinks - *where
necessary* - in /usr/local/bin back to the service component's `bin_dir`.


### Executables required from an interactive session

We reject adding a PATH setting to `/etc/environment` in favour of the
above approach; where commands are intended to be used from an interactive
session, we currently recommend creating symlinks in `/usr/local/bin`.


## Appendix: additions to the build system

### Adding additional configuration directories

In some cases, there are additional data files or directorys, that are not
included in the standard pip build, that need to be added to the tarball
that will be installed for the service.

(An example might be: the testr.conf file from tempest, for instance.)

These extra files can be included in the venv by adding the details to the
`_services_default` in `ardana-dev-tools/ansible/roles/venv/default/main.yml`.
An example is as follows:

```
 _services_default:
   nova:
     sources:
       nova:
         - file_a
         - dir_b
         - ...
       oslo.messaging:
         - file_a
         - dir_c
         - ...
```

The above '_services_default' YAML for the 'nova' component will copy any extra
directories recursively; their content being placed in the resulting exploded
tarball as follows:

/opt/stack/venv/nova/
                 share/
                   nova/
                     file_a
                     dir_b/...
                     ...
                   oslo.messaging/
                     file_a
                     dir_c/...
                     ...

Note that these 'extra files' are shared between *every* service component that
uses the same underlying packaged venv.
