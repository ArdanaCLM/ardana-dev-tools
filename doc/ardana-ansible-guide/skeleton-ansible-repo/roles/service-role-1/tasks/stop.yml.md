
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


# The `stop` verb stops the service on a system

The `stop` verb must perform all stop procedures required to make the associated
role stop on the host OS. The preferred method to stop
the service is to use the host os systemd method.

Currently work to automatically implement the required service systemd script is
being done in the os-svc-daemon ansible component in the os-service-install
element which can be found in ardana/ardana-dev-tools git repo. The `install` verb
should have used the os-svc-daemon to create the required systemd files for the
service.

## Behaviour
- The `stop` verb should skip the task if called and the service is not running
- If the service could not be stopped for any reason the ansible task should fail.

## Ansible Examples
For examples of using systemd services in ansible see
[Manage services](http://docs.ansible.com/service_module.html) in the ansible
system modules documentation.

