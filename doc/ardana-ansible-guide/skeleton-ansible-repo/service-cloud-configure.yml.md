
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


# The service cloud configure playbook

The purpose of a service deploy playbook is to bring the full set of service
components into a running state such that the overall service is operational,
where operational implies that the full set of service APIs can be accessed to
administer and use the service. For some services to be usable by a regular
non-admin user, additional configuration tasks need to be carried out via the
API, e.g.:

- Setup of nova flavors.
- Setup of cinder volume types.
- Loading of an initial set of glance images.

The convention in Ardana is to code each of these cloud configuration tasks as
individual tasks within the &lt;service&gt;-cloud-configure role on the
&lt;service&gt;-ansible repo, e.g. the nova-cloud-configure role contains
an `add_flavors` task. The execution of all of the cloud configuration tasks
for a single service is carried out by a per-service cloud-configure playbook,
e.g. nova-cloud-configure.yml:

    - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
      sudo: yes
      roles:
      - nova-cloud-configure

      # All these tasks should be set to run-once
      tasks:
      - include: roles/nova-cloud-configure/tasks/add_flavours.yml

Note that all &lt;service&gt;-cloud-configure tasks should be run-once tasks,
i.e. they only need to be executed on one node over the course of a single
Ansible playbook run.

The set of per-service cloud-configure playbooks will be invoked by a
top-level ardana-cloud-configure.yml playbook. ardana-cloud-configure can be
optionally run (based on a flag) as part of or in tandem with ardana-deploy. The
end result of a ardana-deploy + ardana-cloud-configure run is a cloud in which
non-admin users can carry out regular operations, such as booting a VM,
creating volumes, etc. This is an optional phase of a deploy, as some
customers will not want the deploy machinery to do any initial configuration
of the cloud itself.
Note that ardana-cloud-configure (or any of the constituent per-service
cloud-configure playbooks) are not designed to act as a general wrapper for
Openstack APIs used to administer the cloud. So in cases where a customer
does use the cloud-configure phase for the initial configuration of the cloud,
alternative tooling (which exercises the Openstack API) will be used for
further administration, such as the uploading of new images to glance, setup
of new flavors, etc.

TODO: Show example of service-cloud-configure task, e.g. add_flavours.yml.
