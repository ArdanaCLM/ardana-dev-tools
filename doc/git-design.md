
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


# Design of the (customer-side) git layout

It's a requirement that we have some way to merge changes that we deliver
as an "upstream" to our customers, and to manage their site configuration.
For this purpose, we've settled on a simple idiomatic use of git.

The lifecycle we envisage is described below; how that is seen by the
customer (or developer) follows each section. For each stage we finally
give the technical details should a user (or developer) want to look
under the hood (or tinker with the contents).


## Initialisation

On a new deployment of a never-before-seen system, the initial stage
requires the preparation of a git repository under ~/openstack.

### User experience

The deployer provisioning runs the ardana-init-deployer script automatically;
this calls

    ansible-playbook -i hosts/localhost git-00-initialise.yml

### Technical result

The ~/openstack directory is initialised as a git repo (if it's empty). That
is prepared with four empty branches: ardana, site, ansible and cp-persistent.
The use of each of these branches is detailed below.


## Receive a new Ardana OpenStack drop

A customer receives a new deployer image. They have to merge any configuration
changes into their own config; this is a manual step, although the standard
git tools may be brought to bear to achieve this.

### User experience

The deployer provisioning runs the following playbooks:

    ansible-playbook -i hosts/localhost deployer-init.yml
    ansible-playbook -i hosts/localhost git-01-receive-new.yml

the latter of which puts the new content directly onto the 'ardana' branch.
That branch is merged to the 'site' branch; the merge may require a
manual review and commit by the customer.

### Technical result

After the import step, there is a new commit on the 'ardana' branch
with the latest upstream deployer content on it. This looks much like
the content of the ~/openstack directory as it was prior to the
introduction of the git workflow.

The ~/openstack repo will be checked out to the 'site' branch and the
results of the merge left in place for review by the user.


## User cycles on configuration

The user edits their configuration until they are happy with it
on the 'site' branch in their ~/openstack repository.

### User experience

The CI system simply copies a configuration unconditionally to
the ~/openstack/my_cloud/definition directory and commits it there.

Any configuration changes must be committed prior to continuing;
the `config-processor-run.yml` script will abort with a message
to that effect if that condition is not met.

### Technical result

The 'site' branch gets a configuration under the my_cloud/definition
subdirectory.


## Run the configuration processor

The configuration processor takes as input the user's configuration,
and also any persistent data saved from a previous run. (That data
contains things such as the allocation of roles to servers, etc.)

It produces as output a set of ansible variable settings (amongst
other input to the ansible playbooks); and may update its
persistent state.

### User experience

The user executes

    ansible-playbook -i hosts/localhost config-proessor-run.yml

as before; however, the CP persistent state and the ansible
outputs now reside on different branches, not immediately
visible to the user.

If the CP run was unsuccessful, the user may continue to edit and
commit to their 'site' branch. An `--amend` commit is acceptable
here.

### Technical result

A scratch directory is prepared to run the CP in, to wit,
~/scratch/cp. The site configuration is checked out into it.
Atop this is laid any saved persistent state for the CP,
which is taken from the head of the 'cp-persistent' branch.

Updated CP persistent data is temorarily stashed to the
'staging-cp-persistent' branch; ansible output to the
'staging-ansible' branch.

The reason for this is that, until a deployment actually occurs,
there is no guarantee that any additional CP state accruing will gain
any measure of real-world semantics by being used for a deployment.
We always reset the inputs to the CP to the last *deployed* persistent
state.


## Prepare and run a deployment

A deployment area is prepared to run an update or a deploy from.
At this point we consider the staged output from the CP to be 'live' -
promoting the commits to the long-lived 'ansible' and 'cp-persistent'
branches.

### User experience

The user readies a deployment area by running

    ansible-playbook -i hosts/localhost ready-deployment.yml

from the ~/openstack/ardana/ansible directory. This will prepare a
scratch directory with the appropriate contents in it under
`~/scratch/ansible/next/ardana/ansible`. The deployment may be
continued via:

    cd ~/scratch/ansible/next/ardana/ansible
    ansible-playbook -i hosts/verb_hosts site.yml

### Technical details

The tip of the `staging-ansible` and `staging-cp-persistent` branches
are laid down upon the `ansible` and `cp-persistent` branches; the
former pair are then deleted.

The tip of `site`, `ansible`, and `cp-persistent` are tagged with
a time-stamped tag to indicate when the deployment was readied.

Two working areas are laid out underneath ~/scratch/ansible. The
`next/` directory holds the latest deployment tree. Alongside this,
the `last/` directory holds the previous tree - that is, the one
constructed from the previous timestamps.

The thinking behind this is that, whilst we currently don't use
the former ansible state for upgrades, that any topology change
will require ansible to know where services _used_ to run in order
to successfully find and disable them.

At the moment, the best use of this directory is as a convenient tree
to run `diff` from.

