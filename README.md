#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017-2018 SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

# Ardana Developer Tools

This repo contains all of the tools needed to setup a system as an Ardana
development environment (DevEnv).

The DevEnv uses [Vagrant](https://docs.vagrantup.com/v2/why-vagrant/)
to create build & test environments in libvirt managed VMs, with
[Ansible](http://docs.ansible.com/) being used to manage the configuration
of the Vagrant VMs, including driving the deployment of clouds using Ardana,
which is itself implemented in Ansible.

## Setting up the Ardana DevEnv
You can setup the DevEnv by running the *bin/astack.sh* script, which will
always attempt to setup your DevEnv _unless_ you specify the *--no-setup*
option, before trying to stand up a test cloud.

Or if you just want to setup the DevEnv without standing up a test cloud
then you can run the *bin/dev-env-setup* script.

In either case you may be told that you need to re-login if the setup
process needed to add you to any relevant system administration groups.
See below for more details.

## Documentation
This README contains a getting-started guide for the Ardana DevEnv.
The remainder of the documentation related to Ardana is located in the
top-level doc dir on this repo.

Key documentation items are:
- [Developer workflow](doc/dev-workflow.md): When you have the environment
up and running,  this provides details on the general Ardana developer workflow
for testing changes in different parts of the Ardana Openstack release.
*NOTE*: This is somewhat out of date and needs updating.
- [Trouble-shooting](doc/troubleshooting.md): For known issues and workarounds.
*NOTE*: This is somewhat out of date and needs updating, with most of the
troubleshooting issues now being automatically addressed/resolved by the
setup process.
- [Ardana Ansible Guide](doc/ardana-ansible-guide/ardana-ansible-guide.md): A set of docs
providing instructions on the writing of Ansible code for services, including a
full description of the layout of a service Ansible repo.

## Things to be aware of before getting started

There are a few important issues you should be aware of before
getting started.

### Support Linux distributions

The following are fully supportted and expected to work without significant
effort:

* Ubuntu 16.04 (Xenial) and 14.04 (Trusty)
* openSUSE Leap 42.3 and 42.2

The following should probably work, but may require tweaks and/or manual
intervention:

* Ubuntu 18.04 (Bionic)
* openSUSE Leap 15

You should be able to get things working on these but will need to manually
add appropriate zypper repos to your system to be sure.
* SLE 12 SP3
  * Need to ensure you have SLE Server is SCC registered to have access to
    Pool & Update repos
  * Need to add the SLE SDK Product/Addon
  * Need [devel:languages:python](https://download.opensuse.org/repositories/devel:/languages:/python/SLE_12_SP3/devel:languages:python.repo) for SLE 12 SP3
  * Need a version of *jq*, version 1.5 or later, installed.

### Paswordless sudo must be setup

It is assumed that you have setup passwordless sudo for your account.
If not you can do so by running a command like the following:

    % echo "${USER} ALL=(ALL:ALL) NOPASSWD:ALL | \
        sudo tee /etc/sudoers.d/${USER}

### First run may require re-login

The first time you run astack.sh, or the dev-env-setup script or the
ansible dev-env-install.yml playbook, if the libvirt and KVM services
weren't already installed, or you aren't a member of the associated
groups, then you may get an error due to your account not being a
member of the required groups for access to Libvirt & KVM system
resources.

Since the system groups are usually setup when installing the relevant
system packages which provide these services, if the DevEnv setup process
has just installed the packages, or you are not already a member of the
associated group, your existing login session won't be a member of the
groups, even though the setup process will have now added you.

To rectify this you will need to log out and log back in again, or
otherwise start a new session. Note that if you have logged in via a
graphical desktop environemnt this will require you to log out of the
graphical desktop sesssion.

Once you have logged in again, and confirmed that your account has the
required group membership by running the *id -nG* command, you can the
re-run the astack.sh, dev-env-setup or dev-env-install.yml playbook to
complete the setup process.

### Deployment Style

Ardana supports two mutually exclusive styles of deployment:
- SOC/CLM: Consume inputs built by the SUSE Open or Internal Build
Services (OBS or IBS) to deploy a cloud
- Legacy: Builds all inputs locally and uses them to deploy a cloud

#### SOC/CLM Deployment Style
The SOC/CLM deployment doesn't need to build the venvs locally; instead
it uses RPMs containing pre-built venvs and the Ardana ansible sources
to setup the deployer and bring up the cloud.

SOC/CLM mode is the default, and is implicitly implied if any of the
various *--c8...* or *--c9...* option flags are specified.

This is the default deployment mode.

#### Lecacy Deployment Style
The original Ardana developer environment was based around building all
of the services as Python Virtual Enviroments, here after referred to as
*venvs*.  To support this we use Vagrant to bring up Build VMs for each
of the supported platforms, which are used to create the required venvs
for each platform.  To do this we build platform specific wheels from
either locally cloned sources, or PyPI pips, and then use those wheels
to construct the venvs, leveraging persistent caches for the wheels and
the built venvs to accelerate the build process.

These venvs, and the associated Ardana ansible sources are then packaged
up in a "product" tarball which is used to setup the deployer and deploy
the cloud.

To enable legacy mode deployment, you must specify the *--legacy* option
to the astack.sh command

### Vagrant version

The Ardana Legacy style CI infrastructure uses Vagrant 1.7.2; however
in early 2017 HashiCorp shutdown gems.hashicorp.com, used by Vagrant
1.7.2, and as a result Vagrant 1.7.2 is no longer able to build plugins.
However we can use Vagrant 1.7.4 to build compatible plugins and then
downgrade to Vagrant 1.7.2 again. This is handled automatically by the
dev-env-install.yml playbook.

The use of such an old version of vagrant is due to the need to share
some of the CI testing resources with a legacy testing environment that
expects this version of Vagrant.

#### Development environments and Vagrant version
NOTE: If you want to avoid this upgrade/downgrade of vagrant, you can set
the ARDANA_VAGRANT_VERSION environment variable to the value of a newer
supported version of Vagrant, e.g. 1.8.7.  For example

    export ARDANA_VAGRANT_VERSION=1.8.7

Additionally the *astack.sh* driven DevEnv uses Vagrant version specific
plugin environments, located in *~/.cache-ardana/vagrant/<version>/home*.
This means you can easily switch between Vagrant versions without having
to remember to delete the *~/.vagrant.d* directory anymore. This is done by
the *bin/ardana-env* script which sets up the VAGRANT_HOME env var to point
to the appropriate home area for the selected ARDANA_VAGRANT_VERSION, which
defaults to 1.7.2 if not specified, and subsequent *astack.sh* runs will
use the ansible/dev-env-install.yml playbook that will detect that Vagrant
plugins are missing/out-of-date, and re-install them.

If you have upgraded you system, or copied your account from one system to
another you may want/need to detele any vagrant home areas to ensure that
they get rebuilt the next time you run astack.sh, e.g.

    rm -rf ~/.cache-ardana/vagrant/*/home

##### Supportted Vagrant versions

Currently the Ardana DevEnv only supports the following Vagrant versions:

1. 1.7.2 (Uses 1.7.4 to build the plugins)
2. 1.7.4
3. 1.8.7 (Probably any 1.8.x really)

Newer versions of Vagrant will work for SLES only deployments, however
RHEL compute networking is incorrectly configured when the VMs are being
created leading to deployment errors.

#### vagrant-libvirt dependency

The primary Vagrant provider supported by Ardana is libvirt, requiring
the vagrant-libvirt plugin.

The default DevEnv/CI version (1.7 stream) is based on the rather old
0.0.35 based released, customised with changes to support:

* Using virtio-scsi as the SCSI controller model, rather than the normal
LSI default.
* Redirecting the console PTY device to a file via the added libvirt.serial
action.

The newer Vagrant (1.8+) streams now select the latest version of the
vagrant-libvirt plugin currently available (0.0.43), dynamically patching
it to add support for specifying virtio-scsi as the default SCSI controller
model; this is currently required because the locally built Vagrant box
images we create are virtio-scsi based and will fail to boot if brought
up with the LSI model SCSI controller.

### Ansible version

The Ardana OpenStack ansible playbooks, as well as those in the DevEnv
(ardana/ardana-dev-tools.git repo) repo, have not been updated to work
with Ansible 2.x, and currently are only verified to work correctly with
Ansible 1.9.

A utility, ardana-env, is provided in the ardana/ardana-dev-tools.git
repo's bin directory, which will setup the runtime environment with an
appropriate version of ansible installed in a persistent virtualenv
under the ~/.cache-ardana area.  To use it, eval the output of the
command, as follows:

    eval "$(ardana-dev-tools/bin/ardana-env)"

Alternatively if you want to do this manually, see the section
on installing Ansible in a Python virtual environment in the
[Trouble-shooting](doc/troubleshooting.md) for help getting around
this limitation.


## Cleaning up your test system environment

Before trying to run another cloud deployment, especially when switching
to a different cloud model, please run the cleanup-slave script found in
ardana-dev-tools/bin; this should clean up everything on your system and
leave it ready for a fresh deployment.

If you just want to recreate the same cloud again, you can instead use
then *--pre-destroy* with the *astack.sh* command which will ensure that
any existing instance of the Vagrant cloud is destroyed before bringing
up the specified cloud.

_*WARNING*_: The cleanup-slave is quite destructive and if there are
other, non-Ardana, vagrant libvirt VM's running on the system it will
likely remove them, or break their network configurations, if they exist
in the default libvirt namespaces.


## Deploy Ardana using astack.sh

To simplify deploying Ardana we have created the astack.sh script, found
in ardana-dev-tools/bin, which will perform all the steps necessary to
deploy, and possibly test, your cloud.

This script enables you to setup your development environment and deploy
a legacy style Ardana cloud with a single command line:

    ./bin/astack.sh dac-min

Alternatively you can deploy a new SOC/CLM style cloud by including the
*--c8* or *--c9* option, like:

    ./bin/astack.sh --c8 dac-min

The cloud defaults to _dac-min_, which is a minimal footprint, fully featured
cloud deployment.

NOTE: You *must* specify the name of the cloud to be used as the last
argument on the command line, after all other options, e.g.

    ./astack.sh ... std-min

Add the following parameters for more options:

    --c9                   (Deploy a SOC/CLM 8 style cloud, rather than a legacy
                            style cloud; this will skip the venv build phase
			    similar to the legacy --no-build option)
    --c8                   (Deploy a SOC/CLM 8 style cloud, rather than a legacy
                            style cloud; this will skip the venv build phase
			    similar to the legacy --no-build option, unless the
			    --run-tests option has also been specified along
			    with the --c8-qa-tests option in which case it will
			    build just the additional QA testing venvs using the
			    legacy build process)
    --c8-hos               (Deploy a SOC/CLM 8 cloud using HOS, rather than SOC,
                            branded repos; otherwise the same as the --c8
			    option)
    --no-setup             (Don't run dev-env-install.yml)
    --no-artifacts         (Don't try to download any ISOs, qcow2 or other
                            inputs; will fail if you haven't previously
			    downloaded and cached the required artifacts)
    --no-build             (Don't build venvs, reuse existing packages)
    --pre-destroy          (Destroy any existing instance of the Vagrant
                            cloud before trying to deploy it)
    --no-config            (Don't automatically compile the cloud model and
                            prepare the scratch area after previsioning cloud;
                            implies --no-site)
    --no-site              (Don't run the site.yml play after previsioning cloud)
    --run-tests            (Run the tests against cloud after a successful test)
    --run-tests-filter FILTER
                           (Use specified filter when running tests; this
			    implicitly selects --run-tests so only need to
			    specify one. Default is 'ci' and can specify any
			    filter name found in roles/tempest/filters/run_filters
			    directory under ~/openstack/ardana/ansible on a deployed
			    system, or in the ardana/tempest-ansible.git repo)
    --tarball TARBALL      (Specify a pre-built legacy style deployer tarball
                            to use)
    --ci                   (Sets the same options used by the legacy deployment
                            mode CI)
    --guest-images         (Builds and uploads guest images to glance)
    --rhel                 (Builds RHEL artifacts for inclusion in product tarball)
    --rhel-compute         (Configures compute nodes to be RHEL based)

### Useful tools

Once a cloud has been deployed, astack.sh will ensure that these files are
created under the ardana-vagrant-models/${cloud}-vagrant directory that can
make it easier to work with an astack managed cloud.

#### astack-ssh-config

This is the output of the vagrant ssh-config command, generated with
the same environment settings used to deploy the cloud, so it has the
correct user and home directory settings configured for the vagrant
image being used.

This means you can run ssh or scp command to your cloud using this file
as an argument to the ssh -F option, e.g.

    % cd ardana-vagrant-models/dac-min-vagrant
    % ssh -F astack-ssh-config controller

#### .astack-env

This is a dump of the environment setting that were active when the cloud
was being deployer, which can be sourced to setup the same environment
if you wish to run additional commands against the same cloud.

#### ardana-vagrant

This is a simple wrapper script that leverages the .astack-env file to
setup the environment appropriately and then runs the vagrant command
against the cloud, e.g.

    % ./ardana-vagrant ssh controller

#### ardana-vagrant-ansible

This is a simple wrapper script that leverages the .astack-env file
to setup the environment appropriately and then runs ansible-playbook
command against the cloud, using the vagrant.py script found under
ardana-dev-tools/ansible/hosts as the inventory file, so that ansible
dynamically determines the appropriate inventory data for the running
cloud from Vagrant, e.g.

    % ./ardana-vagrant-ansible ../../ansible/cloud-setup.yml

If no arguments are specified it will run the cloud-setup.yml playbook
against the cloud; if you don't want to run the ardana-init command
again, you can specify the --skip-ardana-init option.

## Deploying manually using Legacy style

### Hardware

Because the steps below require libvirt, you'll need to follow them on either
real hardware, or in a VM that supports nested virtualization. If

    grep 'vmx\|svm' /proc/cpuinfo

doesn't show your CPU flags, you're out of luck. Maybe try enabling virtualization
(VXT) in your BIOS.  NOTE: On HP Z640 Workstations, the CPU vmx flag will appear
in /proc/cpuinfo even though VT-X is not enabled in the BIOS, so check that /dev/kvm
exists or do an lscpu.

You'll want at least 42 GB RAM for a standard install.

### Passwordless sudo

Several of the following commands require root privileges.
To enable passwordless sudo, edit the sudoers file as follows:

    sudo visudo

Add this line to the file:

    <username> ALL=(ALL) NOPASSWD: ALL

### Proxies and VPN

If you require a proxy to reach the internet you should ensure
that you have a proxy configured for both http and https, and
that the https proxy does not itself use a secured connection.

For example, a typical proxy setup would be as follows:

    http_proxy=http://proxy.example.com:8080
    https_proxy=http://proxy.example.com:8080
    no_proxy=localhost,devhost.example.com

#### Remote/Slow connection suggestions

If you are working remotely using a VPN connection, or in an office with a
poor/unreliable connection to the specified ARDANA_SITE servers then you can
increase the chances of successful building the sources by increasing the
following timeouts via setting the relevant environment variables:

1. ARDANA_VENV_PIP_TIMEOUT - default 60
2. ARDANA_VENV_EXT_DL_TIMEOUT - default 60

### Installing SUSE ROOT CA
Ensure that you have the SUSE ROOT CA installed as detailed at
[SUSE ROOT CA Installation](http://ca.suse.de)

### Installing Ansible
You can install install ansible locally on your system, but be warned
that it is unlikely that it will be a _fully Ardana compatible_ version
as most modern distros will install a newer version of ansible that we
have optimised Ardana for, which may see issues.

For best results we recommend running the ansible-dev-tools playbooks
using Ansible version 1.9.6. This can be done using a Python virtualenv
and we provide the ardana-dev-tools/bin/ardana-env script to set this
up automatically for you; just eval the output it generates, e.g.

    % cd ardana-dev-tools
    % eval "$(bin/ardana-env)"

This creates an appropriate ansible virtualenv, $HOME/.cache-ardana/venvs,
if it doesn't already exist, and activates it.

### Local sites

If there is a local site defined with mirrors for Python and system packages then you
can set the ARDANA_SITE environment variable to specify your local site. The default
site is in Provo. Note that we do this automatically for all CI runs.

For example,

    export ARDANA_SITE=provo

*NOTE*: Currently the only defined site is Provo, which is therefore the
default site, so this step isn't necessary.

### Steps to manually setup and verify the developer environment

The `ansible` directory contains all of the ansible code to setup and verify
the developer environment. If you do not have password-less sudo setup for your user
you will need to add `--ask-sudo-pass` to the ansible-playbook commands, or set
ask\_sudo\_pass to True in your ansible configuration file (e.g. ~/.ansible.cfg or globally
for all users in /etc/ansible/ansible.cfg).

Now run the following commands:

    cd ansible
    ansible-playbook -i hosts/localhost dev-env-install.yml
    ansible-playbook -i hosts/localhost image-build-setup.yml


At this point you should also check that you have rights to access libvirt as a normal
user. The permissions should have been added as part of the install process, but you may
need to log out then back in again.

You can check that your system is configured correctly and that you are a member
of the necessary groups by running the following validation playbook:

    ansible-playbook -i hosts/localhost dev-env-validate.yml


### Download the SLES ISOs

SLES ISOs need to be downloaded to support the creation of the customised Vagrant
images that we is required for creating the build and cloud VMs.

To the latest configured SLES ISOs, run the following on the command line:

    % env ARDANA_SLES_ARTIFACTS=true \
        ansible-playbook -i hosts/localhost get-sles-artifacts.yml

This can take a while to run as the we need to download ~5G of ISOs.

NOTE: These ISOs are cached under the ~/.cache-ardana tree so you should
only need to do this very infrequently, and the astack.sh command will take
care of this step automatically.


### Build the SLES Vagrant Image

You will now be able to build a SLES vagrant image for use in building venvs and
booting the test infrastructure.

    % env ARDANA_SLES_ARTIFACTS=true \
        bin/build-distro-artifacts

NOTE: This script ensure the latest versions of any artifacts are downloaded.

### Create the Legacy style Deployer Appliance

Now that we have a base disk image, we can build the customer deliverable
Deployer Package. This will contain all of the Ardana ansible code and all of the
required venvs for a Ardana deployment.

#### Boot Build VM

The next step is to set up the VM that's used to run package builds on. This VM
can remain in place - it's possible to update a local copy of (say) nova, and
update a single packaged venv, and by leaving the build machine booted (or more
accurately by not destroying it) you can make use of the pre-built venvs when
rebuilding.

Not setting the default vagrant provider, or setting it to `libvirt`, should
use libvirt to create the virtual machines. Currently libvirt is the only
supported provider.

    % cd ardana-dev-tools/build-vagrant
    # to create virtual machines on the local system using libvirt
    % export VAGRANT_DEFAULT_PROVIDER=libvirt
    % vagrant up

_N.B. if you are using libvirt as the vagrant provider, be aware that the
default dnsmasq setup for the created VMs uses the first item in your
resolv.conf file as the "upstream" DNS server.  To work around this, add any
required internal servers to /etc/hosts on your workstation and restart dnsmasq.
Those servers will now be resolvable from the created VMs._

#### Virtual Environment Builds

The process assumes that any services that you are actively developing are cloned
at the same level as ardana-dev-tools. The system will pick up these repos and any
changes in them. It is your responsibility to check out the commit that you want
to test in these repos.

For all other services, the build system will clone the latest code for the
services and use that.

For example, the following tree would mean that glance and nova repos on the local
workstation are used and that all other services are cloned directly from git

    % cd ardana-dev-tools
    % ls ../
    glance  ardana-dev-tools  nova

Now, the venvs can be built and packaged up using the build virtual machine.

    % bin/build-venv.sh

This process should result in packaged venvs being created in the ardana-dev-tools/scratch
directory: these have names like `nova-{version}.tgz`. Those packages are used
in the following steps. (For more details on this process, and additional options,
see the [longer notes](build-vagrant/README.md).

If you are short of resources, you may choose to remove the build VM at this point :

    % vagrant destroy

### Create the Virtual Cloud VMs

Once the above is completed you will be able to start the `vagrant up` process
to initialise the virtual test infrastructure by creating a number of VMs
which represent the physical servers in an Ardana OpenStack cloud.

The development environment provides a set of cloud definitions that can be used:

* minimal: Cloud in a box

    A minimal single node cloud running a reduced number of services, disabling some of the Metering, Monitoring & Logging (MML) stack using a "hack"

* deployerincloud: A 3 node cloud

    Cloud Control Plane (1 node: ha-proxy, Apache, MySQL, RabbitMQ, Keystone, Glance, Horizon, Nova, Neutron ) + 2 Compute Nodes, with deployer on controller node. Uses a simplified Swift ring model with EC disabled.

* deployerincloud-lite: A 3 node cloud

    A cutdown version of deployerincloud using same "hack" as minimal to disable some of the MML stack.

* standard: A 7 node single region cloud

    Cloud Control Plane (3 nodes: ha-proxy, Apache, MySQL, RabbitMQ, Keystone, Glance, Horizon, Nova, Neutron ) + 3 Compute Nodes + 1 Deployer. Uses a more complex Swift run model with EC enabled.

* std-min: A 4 node single region cloud

    A cutdown version of standard cloud with 1 controller and 2 computes removed.

* std-3cp: A 5 node single region cloud

    A cutdown version of standard cloud with 2 computes removed.

* std-3cm: A 5 node single region cloud

    A cutdown version of standard cloud with 2 controllers removed, and simplified Swift ring model with EC disabled.

* dac-min: A 2 node single region cloud

    A cutdown version of std-3cm with just 1 compute and deployer at controller (dac).

* std-split: A 5 node single region multi-control plane cloud

    Based on the standard cloud with 2 compute removed, using 3 single node control planes, 1 for core openstack services, 1 for DB & RabbitMQ, and 1 for MML stack, though Swift services are shared among all 3 to allow for a complete Swift ring model with EC disabled. Control node sizing are minimised to match running service requirements.

* mid-size: A multi-control plane, multi region cloud

* multi-cp: A more complex multi-control plane multi-region cloud

WARNING : The std-split, mid-size & multi-cp models may not be stable/functional right now.

Each variant has its own vagrant definition, under the ardana-vagrant-models directory, and associated cloud model defined in the ardana-input-model repo, under the 2.0/ardana-ci directory.

For example to get vagrant to create the VMs needed for a std-min cloud with default node distro setting use the following command:

    cd ../ardana-vagrant-models/std-min-vagrant
    vagrant up

NOTE : vagrant up provisions all the nodes in your cloud. During the provisioning of the deployer node we
create a tarball of all the ansible deployment code, and all the venvs we built earlier. The provisioning
then copies this tarball to the deployer, unpacks it and calls the ardana-init.bash script. At
which point the deployer is setup and ready to deploy a running cloud.

### Setting up vagrant VM for Ardana

After the `vagrant up` you will have a number of booted VMs, and a booted and partially
configured deployer VM, where the deployer tarball has been exploded and the initial
pre-configure script has been run. This generates the ardana area, where the next set of ansible
playbooks will be run from, and installs the ansible venv that will run those playbooks.

    vagrant status
    Current machine states:

    deployer                  running (libvirt)
    cp1-0001                  running (libvirt)
    cp1-0002                  running (libvirt)
    cm1-0001                  running (libvirt)

All of the administration from this point is done through the deployer VM.

Log in to the deployer node and then run commands to configure the system.

    vagrant ssh deployer

### Running the Configuration Processor and cloud models

The deployer is now populated with the directory structure that we intend to use
for customers. The main directory is ardana/ under which there are 4 sub-directories:
examples/; my_cloud/; tech-preview/; and openstack/.  Example cloud definitions are included in
/ardana/examples.  The cloud to be built by CP run is defined in
/openstack/my_cloud/definition (CP inputs, networking, servers, storage etc including
Swift ring definitions and Nova zone definitions).

The inputs are held in the ardana-input-model repo which is now on the deployer.
Working cloud definitions that we come up with will be held in 2.0/examples.
The standard inputs are under 2.0/ardana-ci/standard.  The service-specific CP inputs
are to be found under 2.0/services, and on the deployer under openstack/ardana/services.

The ardana-ci/standard inputs should be copied to openstack/my_cloud/definition.  You
will need to copy the appropriate inputs if you intend to use an alternative cloud model.
openstack-<version>/ardana-input-model/2.0/examples are copied to ardana/examples.

We recommend using the standard cloud definition (i.e. the definition in
openstack-<version>/ardana-input-model/2.0/ardana-ci/standard) to begin with.

Note that the whole of the ardana/ directory is under git control. More detailed
information about this can be found in the [Git design document](doc/git-design.md)

To run CP:

    cp -r ~/ardana-ci/standard/* ~/openstack/my_cloud/definition/
    cd ~/ardana
    git add -A
    git commit -m "My config"
    cd ~/openstack/ardana/ansible/

We have modified the config-processor-run.yml playbook to turn on CP encryption of
its persistent state and Ansible output.  If you run the playbook as follows:

    ansible-playbook -i hosts/localhost config-processor-run.yml

You will be prompted for an encryption key, and also asked if you want to change the
encryption key to a new value, and it must be a different key.  You can
turn off encryption by typing the following:

    ansible-playbook -i hosts/localhost config-processor-run.yml -e encrypt="" \
                     -e rekey=""

To run playbooks against the CP output:

    ansible-playbook -i hosts/localhost ready-deployment.yml
    cd ~/scratch/ansible/next/ardana/ansible

If your input model includes Ardana Hypervisor nodes, providing Virtual Control
Plane VMs, then you need to run the following command to setup the hypervisor
nodes, provision the VCP VMs and start them:

    ansible-playbook -i hosts/verb_hosts ardana-hypervisor-setup.yml

If you've turned-off encryption, type the following:

    ansible-playbook -i hosts/verb_hosts site.yml

If you enabled encryption, type the following:

   ansible-playbook -i hosts/verb_hosts site.yml --ask-vault-pass

Enter the encryption key that you used with the config processor run when prompted
for the Vault password.

In a baremetal re-install case, you'll need to wipe partition data on non-os disks to
allow osconfig to complete successfully.
If you wish to wipe all previously used non OS disks run the following before site.yml:

    ansible-playbook -i hosts/verb_hosts wipe_disks.yml

This will require user confirmation during the run. This play will
fail if osconfig has previously been run.

To restrict memory usage below default 2g by elasticsearch you can pass lower amount.
Minimum value is 256m and it should allow operation for few hours at least. If you
plan system to run for longer period please use larger values.

    ansible-playbook -i hosts/verb_hosts site.yml -e elasticsearch_heap_size=256m

For more information on the directory structure see TODO Add new link if possible [here].

Once the system is deployed and services are started, some services can be
populated with an optional set of defaults.

    ansible-playbook -i hosts/verb_hosts ardana-cloud-configure.yml

If you are running behind a proxy, you'll need to set the proxy variable as
we download a cirros image during the cloud configure

    ansible-playbook -i hosts/verb_hosts ardana-cloud-configure.yml \
                     -e proxy="http://<proxy>:<proxy_port>"

For now this:

    Downloads a cirros image from the Internet and uploads to Glance.

    Creates an external network - 172.31.0.0/16 is the default CIDR.
    You can over-ride this default by providing a parameter at run time:

    ansible-playbook -i hosts/verb_hosts ardana-cloud-configure.yml \
                     -e EXT_NET_CIDR=192.168.99.0/24

Other configuration items are likely to be added in time, including additional
Glance images, Nova flavors and Cinder volume types.

## Configuration jinja2 templates
Configuration jinja2 templates, which are customer editable, are included in
openstack/my_cloud/config.

## Exercising the deployed Cloud
After running through the Ardana steps to deploy a cloud, you can access API services on
that cloud from the deployer by first running the following on the deployer vm:

    ansible-playbook -i hosts/verb_hosts cloud-client-setup.yml

After running this playbook, the /etc/environment file is updated for subsequent logins,
but you will need to source it to change the settings of the current shell.

    source /etc/environment

## Installing the CA certificate for the TLS endpoints into the deployer
To access endpoints terminated by TLS, you need to install the CA certificate that
signed the TLS endpoint certificate.

    ansible-playbook -i hosts/localhost tls-trust-deploy.yml

The core services (Keystone, Nova, Neutron, Glance, Cinder, Swift) are all operational,
and new services are being integrated continually.   "nova endpoints"  is a useful
command to see the current service catalog.

Two accounts are set up in keystone. To start using services, source the service.osrc
file. For keystone operation source the keystone.osrc file. Note that the keystone cli
is deprecated and won't work anymore, instead use the openstack cli.

A note on CA certificates: If you're going to connect to API from outside of the cloud,
you need to install the CA certs or run with the insecure option. The CA certificate
can be found from the following location in the deployer:

    /usr/local/share/ca-certificates/ardana_frontend_cacert.crt

Copy it to the following directory in your workstation:

    /usr/local/share/ca-certificates/

And run:
    sudo update-ca-certificates

Now you can run openstack commands to encrypted endpoints.

    cd ~
    . ./service.osrc

    nova flavor-list
    +----+--------------+-----------+------+-----------+------+-------+-------------+-----------+
    | ID | Name         | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
    +----+--------------+-----------+------+-----------+------+-------+-------------+-----------+
    | 1  | m1.tiny      | 512       | 1    | 0         |      | 1     | 1.0         | True      |
    | 2  | m1.small     | 2048      | 20   | 0         |      | 1     | 1.0         | True      |
    | 3  | m1.medium    | 4096      | 40   | 0         |      | 2     | 1.0         | True      |
    | 4  | m1.large     | 8192      | 80   | 0         |      | 4     | 1.0         | True      |
    | 5  | m1.xlarge    | 16384     | 160  | 0         |      | 8     | 1.0         | True      |
    | 6  | m1.baremetal | 4096      | 80   | 0         |      | 2     | 1.0         | True      |
    +----+--------------+-----------+------+-----------+------+-------+-------------+-----------+


    nova endpoints
    ...

Note that currently most services are "empty" - e.g there are no images loaded in Glance and
no networks or routers configured in Neutron.

Alternatively you can run the configured tempest tests against keystone with the following commands:

    cd ~/scratch/ansible/next/ardana/ansible
    ansible-playbook -i hosts/verb_hosts tempest-run.yml

## Using Vagrant
The use of Vagrant in Ardana is to create a virtual test environment.  The use of Vagrant
features is to setup a minimal installation on the Resource and Control Plane servers
and to fully prep the deployer server such that it is ready to start deploying to the
Resource and Control Plane servers.

## Using Ansible
Ansible performs all of the configuration of the deployer and of the resource and
control plane servers.  For use in the developer environment it is recommended that
you use the following to prevent ssh host key errors:

```
export ANSIBLE_HOST_KEY_CHECKING=False
```

All of the building and provisioning is controlled by ansible, and as such the use of
ansible variables can change both what and how things are built.  They can be
specified on the command line directly with the use of `-e<var>=<value>` or they can
be set within a file that is included.  See the ansible documentation for more details,
[Passing Variables On The Command Line](http://docs.ansible.com/playbooks_variables.html#passing-variables-on-the-command-line)

The best way of determining what variables exist is to look through the playbooks themselves.

## Working with Floating IPs
In order to access virtual machines created in the cloud, you will need to create a physical
router on the ext-net. Assuming you have used the above mechanism to create the ext-net, you
can use the following commands on the deployer node, to access the floating IPs.

    vconfig add eth3 103
    ifconfig eth3 up
    ifconfig eth3.103 172.31.0.1/16 up

This creates a VLAN on eth3 with tag 103 and adds the default-router IP to it.

You can then ping the floating IP (from the deployer node). Remember to add security-group
rules for ICMP and possibly for SSH.

## Setting up routes between Management network and Octavia's Neutron provider network
Octavia, which is the default HA driver for neutron lbaas, requires a route
between its neutron provider network (management network for amphora) and
Ardana OpenStack management network. Run the following playbook on the host
node that runs Ardana OpenStack vagrant VMs to setup this route.

    cd ansible
    ansible-playbook -i hosts/localhost dev-env-route-provider-nets.yml

## Building custom/updated service wheel to modify your standard-vagrant environment
This section details how to build a custom wheel to replace the deployed venv in
your environment. You will likely want to follow these steps if you have
added sources or pips to the requirements.txt, or modified the setup.py(cfg) of your
service package, and therefore need to deploy an updated venv as opposed to
rebuilding your environment.

1. Clone your service repo (ie swiftlm) to a directory parallel to ardana-dev-tools

2. Patch this clone directory with your desired changes

3. Change dir to ardana-dev-tools/build-vagrant
    cd ../ardana-dev-tools/build-vagrant

4. Run the venv-build playbook
    ansible-playbook -i ../ansible/hosts/vagrant.py ../ansible/venv-build.yml -e '{"packages": ["swiftlm"]}'

    which will then create a new tgz under ../scratch-master_<version_name>/swiftlm-20160226T144301Z.tgz

5. scp this new tgz up to the deployer directory at /opt/ardana_packager/ardana-<version>/sles_venv/.

6. vagrant ssh to the deployer and regenerate the packager index:
    sudo /opt/stack/service/packager/venv/bin/create_index --dir /opt/ardana_packager/ardana-<version>/sles_venv/

7. Verify your new package listed in packages:
    cat /opt/ardana_packager/ardana-<version>/sles_venv/packages

8. Do an upgrade of the service:
    ansible-playbook -i hosts/verb_hosts swift-upgrade.yml

## Troubleshooting
Sometimes things go wrong.  Known issues are listed in [troubleshooting](doc/troubleshooting.md)

## Emulating the CI Build & Testing Process
The CI Build and Test process can be more closely emulated by passing the
--ci option to the astack.sh script, e.g. ./astack.sh --ci standard
The primary impact of doing so will be that the user account on the vagrant
VMs will be ardanauser rather than stack. Additionally when creating a standard
cloud, the 3rd compute VM will be created as a RHEL7 rather than SLES VM.
See [doc/dev-workflow.md] for more details.
