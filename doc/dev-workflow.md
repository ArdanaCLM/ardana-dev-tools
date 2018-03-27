(c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
(c) Copyright 2017-2018 SUSE LLC

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.


# Developer Workflow

This README documents the steps that a developer needs to carry out within
the Ardana developer environment in order to test changes to different parts of
the Ardana stack. A change may be a local change on the developer workstation
or a change that has recently pulled onto the developer workstation (e.g. a
rebase). Changes in the following areas are documented:

- Ansible code in ardana-ansible or any of the &lt;service&gt;-ansible repos, e.g.
nova-ansible, neutron-ansible, glance-ansible, etc.
- Ansible code in osconfig-ansible.
- ardana-configuration-processor
- OpenStack source repos, e.g. nova, neutron, glance, etc.
- PyPI package.
- ardana-dev-tools

## Testing a change to ardana-ansible or &lt;service&gt;-ansible repos

In order to test a change in either the high-level playbooks in
ardana-ansible or in one of the per-service ansible repos, first checkout
the repo or repos your want to modify into the same directory as
ardana-dev-tools. So you should have a directory structure like so:

    ardana-dev-tools
    nova-ansible
    cinder-ansible
    ...

Then carry out the following steps to push the changes onto the deployer
appliance and re-run the top-level deploy playbook:

    cd ardana-dev-tools/ardana-vagrant-models/standard-vagrant
    vagrant provision deployer
    vagrant ssh deployer
    rm -fr ~/openstack/my_cloud/definition/*
    cp -r ~/ardana-ci/standard/* ~/openstack/my_cloud/definition/
    cd ~/openstack
    git add -A
    git commit -m "My config"
    cd ~/openstack/ardana/ansible/
    ansible-playbook -i hosts/localhost config-processor-run.yml -e encrypt="" \
                         -e rekey=""
    ansible-playbook -i hosts/localhost ready-deployment.yml
    cd ~/scratch/ansible/next/ardana/ansible
    ansible-playbook -i hosts/verb_hosts site.yml

The last step should execute code that has changed on ardana-ansible or
code on a &lt;service&gt;-repo that is indirectly invoked.

The provision deployer step will sync any &lt;service&gt;-ansible you
have checked out into the deployer. This step will also fetch the latest
deployer code for all the other services that you are not interested in
developing.

## Testing a change to osconfig-ansible
TODO: Create osconfig-ansible repo and populate with initial osconfig content
-- BUG-300.

## Testing a change to ardana-configuration-processor
TODO: BUG-358

When making changes to the ardana-configuration-processor you need to ensure that
the venv it is run from on the deployer is rebuilt after the change.


## Testing a change to an OpenStack source repo
TODO: BUG-86

## Testing a change to a PyPI package
TODO: BUG-11

## Testing a change to ardana-dev-tools
TODO: BUG-357


# Cleanup

Remove old versions of virtual envs from a node by running:

cd ardana-dev-tools/bin
./cleanup-slave

This destroys vagrant VMs from your machine. If you want to remove all VMs,
add the --ci argument.

# Emulating the CI Testing Process
Usage: ./astack.sh --ci standard

There are two reasons to use the "--ci" option:
1) Want to more closely emulate what the real CI system does, e.g. creates
cluster with "ardanauser" account rather than "stack" account
2) Want to trigger CI mode specific testing changes, e.g. create standard 
with 3rd compute as RHEL

Example 1: create COMPUTE-0003 to be RHEL
1) Edit astack.sh and uncomment below lines:
export ARDANA_RHEL_ARTIFACTS=1
export ARDANA_RHEL_COMPUTE_NODES=COMPUTE-0003
2) Run ./astack.sh --ci standard

Example 2: run tempest tests with CI mode
1) cd ardana-dev-tools/ardana-vagrant-models/standard-vagrant
2) bash -x ../../bin/run-in-deployer.sh --ci ../../bin/deployer/run-tests.sh 
--ci standard
