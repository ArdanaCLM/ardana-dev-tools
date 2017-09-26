
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


# Enabling systemd for Openstack service components

This feature is to be used in conjunction with the venv tooling documented
in this directory.  Once the appropriate venv has been installed, systemd
service files can be written with the "setup_systemd" Ansible module.  The
arguments to this module:

  Required:
     service:  The name of the service (e.g. nova-api, swift-proxy, etc.)
     cmd:  The command to use to invoke the service (e.g. keystone-all)

  Optional:
     name: The systemd unit name
        Default: service
     install_dir:  The directory where the service is installed
        Default: /opt/stack/service
     user:  The user name under which the service should run
        Default: stack
     group: The group in which the service should belong
        Default: user
     args:  Any arguments to cmd
        Default: None

The "setup_systemd" Ansible module is modelled closely on TripleO
os-svc-daemon.  It writes /usr/lib/systemd/service/"name".service.
Note that "name" is optional and defaults to "service" for the the
common use case a single systemd unit corresponds to single
service-component directory and a single executable being launched
out of that.  "setup_systemd" also writes
/usr/lib/systemd/service/"name"-create-dir.service which makes
/var/run/"name", and sets ownership of /var/run/"name".  If the
contents of the systemd service files have not changed, then the service
files are left untouched.  Otherwise the systemd files are overwritten.

Once the systemd files have been written, systemd has to be notified of the
changes.

An example use of "setup-systemd" for Keystone:

  In the configure.yml playbook:
     - name: Setup systemd
       setup_systemd: service=keystone user=keystone \
                      cmd=keystone-all

     - name: Notify systemd of changes
       command: systemctl daemon-reload

  In the start.yml playbook:
     - name: Start Keystone
       service: name=keystone state=started
