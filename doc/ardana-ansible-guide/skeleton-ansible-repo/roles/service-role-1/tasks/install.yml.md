
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


# The `install` verb installs the software package(s)

The `install` verb must ready the system for an installation of a packaged venv.
Any run-time dependencies (in terms of system packages) should be installed by
this verb.

Other environmental requirements - such as the existence of user and group accounts
with stable and predictable uid/gids - should also be performed by this verb.

Versions of installed venvs need not be specified - in which case, the behaviour
is to install the latest version found.

In the future, it may be the case that the creation of user accounts is lifted
into the os-config role.

It's possible for multiple service components to share the same venv package as the
source of their executables. The install_package ansible module will correctly
clean up a shared venv when all of its dependent service components are removed.


## Behaviour
- The `install` verb should be rely on the idempotency of the underlying
  ansible modules.
- Care should be taken to ensure that uids and gids are predictable - this is
  a requirement for subsystems that rely on block-shipping filesystems (eg,
  anything that uses drbd).


## Identifying the version installed

Typically, the version installed will simply be the latest. The `bin_dir` and
`config_dir` filters will locate the appropriate directories.

Should it be necessary to determine the version of a package within ansible,
a role should:

- depend upon the package-consumer role;
- use the {{ packages | package_max_version('venv-name') }} J2 syntax.


## Identifying the location of binaries and venv configuration directory

Binaries are stored in {{ 'service-component-name' | bin_dir() }}. For an
explicit version (this will typically not be required) use the syntax:
{{ 'service-component-name' | bin_dir('venv-version') }}.

Similarly, the per-service-component versioned config directory can be
located using {{ 'service-component-name' | config_dir() }}.


## Ansible Examples

    # The venv is packaged up as "nova"
    # Install a service component that uses that source code as "nova-api"
    - name: Install the nova-api service
      install_package: name=nova service=nova-api state=present

    # You need to depend on the package-consumer role to make
    # the 'packages' variable available
    - name: What's the package version of nova?
      debug:
        msg: Version of nova package installed: {{ packages | package_max_version('nova') }}

    # Typically the 'configure', not the 'install' verb, uses this
    - name: Install a configuration file
      template:
        src: nova.conf.j2
        dest: "{{ 'nova-api' | config_dir() }}/nova-api.conf"

