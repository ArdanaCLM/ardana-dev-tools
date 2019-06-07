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

### Supported Linux distributions

The following are fully supportted and expected to work without significant
effort:

* Ubuntu 18.04 (Bionic), 16.04 (Xenial), 14.04 (Trusty)
* openSUSE Leap 15, 42.3 and 42.2

You should be able to get things working on these but will need to manually
add appropriate zypper repos to your system to be sure.
* SLE 12 SP3
  * Need to ensure your SLE Server is SCC registered to have access to
    Pool & Update repos
  * Need to add the SLE SDK Product/Addon
  * Need [devel:languages:python](https://download.opensuse.org/repositories/devel:/languages:/python/SLE_12_SP3/devel:languages:python.repo) for SLE 12 SP3
  * Need a version of *jq*, version 1.5 or later, installed.

### Paswordless sudo must be setup

It is assumed that you have setup passwordless sudo for your account.
If not you can do so by running a command like the following:

    % echo "${USER} ALL=(ALL:ALL) NOPASSWD:ALL" | \
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

Ardana supports deploying SOC/CLM consuming inputs built by the SUSE Open
or Internal Build Services (OBS or IBS) to deploy a cloud using Vagrant.

Which version of SOC/CLM gets deployed depends on whether you use
*--c8...* or *--c9...* options when running astack.sh; SOC/CLM version
9 is the default if no version is specified.

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
another you may want/need to delete any vagrant home areas to ensure that
they get rebuilt the next time you run astack.sh, e.g.

    rm -rf ~/.cache-ardana/vagrant/*/home

##### Supportted Vagrant versions

Currently the Ardana DevEnv only supports the following Vagrant versions
for all testing scenarios:

1. 1.7.2 (Uses 1.7.4 to build the plugins)
2. 1.7.4
3. 1.8.7 (Probably any 1.8.x really)

Newer versions of Vagrant will work for SLES only deployments, however
RHEL compute networking is incorrectly configured when the VMs are being
created leading to deployment errors.

Verified as working for SLES only deployments:
1. 1.9.8 (Probably any 1.9.x, definitely 1.9.5+)
2. 2.0.4 (Any 2.0.x)
3. 2.1.5 (Any 2.1.x)
4. 2.2.4 (Any 2.2.x)

#### vagrant-libvirt dependency

The primary Vagrant provider supported by Ardana is libvirt, requiring
the vagrant-libvirt plugin.

The default DevEnv/CI version is based on the 0.0.45 vagrant-libvirt
release, dynamically patched with some minor changes to support:

* Using virtio-scsi as the SCSI controller model, rather than the normal
LSI default.

NOTE: Since we have stopped using the heavily customised 0.0.35 release
we no longer support the following functionality:

* Redirecting the console PTY device to a file via the added libvirt.serial
action.

NOTE: The Vagrant boxes we build for use with the Ardana DevEnv may fail
to boot if you attempt to use them with a standard, unpatched, version
of vagrant-libvirt because drivers for the default LSI SCSI may not be
included in the image to save space.

### Ansible version

The Ardana DevEnv (ardana/ardana-dev-tools.git repo) tools have been
updated to be compatible with Ansible 2.4.6, though the Ardana OpenStack
ansible playbooks themselves, have not been updated to work with Ansible
2.x, and currently are only verified to work correctly with Ansible 1.9.

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
a SOC/CLM version 9 cloud with a single command line:

    ./bin/astack.sh dac-min

Alternatively you can deploy a SOC/CLM version 8 cloud by including the
*--c8* option, like:

    ./bin/astack.sh --c8 dac-min

The cloud model defaults to _dac-min_ if not specified, which is a minimal
footprint, fully featured cloud deployment.

NOTE: If specifying the name of a cloud model to use, you *must* specify it as
the last argument on the command line, after all other options, e.g.

    ./astack.sh ... std-min

Some useful additional parameters to use:

    --c9                   (Deploy a SOC/CLM version 9 cloud on SLES12 SP4;
                            this is the default, using Devel:Cloud:9:Staging
			    based package repos)
    --c9-milestone MILESTONE
                           (Deploy a SOC/CLM version 9 cloud on SLES12 SP4, using
			    latest available build of specified milestone ISO,
                            for example:
                              --c9-milestone RC7
                              --c9-milestone GMC1)
    --c8                   (Deploy a SOC/CLM version 8 cloud on SLES12 SP3)
    --c8-hos               (Deploy a SOC/CLM 8 cloud using HOS, rather than SOC,
                            branded repos; otherwise the same as the --c8
			    option)
    --sles12sp3            (Use SLES12 SP3 based Vagrant boxes, repos, artifacts;
                            implied default when --c8* options are specified.)
    --sles12sp4            (Use SLES12 SP4 based Vagrant boxes, repos, artifacts;
                            implied default when --c9* options are specified.)
    --legacy               (Deploy a legacy style product tarball based cloud;
                            deprecated and no longer maintained, support will
			    be removed in a future update.)
    --no-setup             (Don't run dev-env-install.yml; must have been
                            previously run)
    --no-artifacts         (Don't try to download any ISOs, qcow2 or other
                            inputs; will fail if you haven't previously
			    downloaded and cached the required artifacts)
    --no-update-rpms       (Don't build local override RPMs for Ardana packages
                            whose repos are cloned beside the ardana-dev-tools
			    repo, using the *bin/updates_rpms.sh* script)
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
    --guest-images         (Builds and uploads guest images to glance)
    --rhel                 (Enables retrieval and builing of RHEL artifacts, e.g.
                            ISOs and qcow2 images for Vagrant box)
    --rhel-compute         (Configures compute nodes to be RHEL based rather than
                            the default SLES; implies --rhel)
    --ibs-prj PRJ[/PKG][@DIST]
                           (Download RPMs from specified IBS project (or specific
                            package if provided) for distro version appropriate
			    repo, or specified repo name if provided, and include
			    them into the NEW_RPMS area that will be created beside
			    the ardana-dev-tools clone. Repeat as many times as
			    needed to add all projects and/or packages desired.)
    --obs-prj PRJ[/PKG][@DIST]
                           (Download RPMs from specified OBS project (or specific
                            package if provided) for distro version appropriate
			    repo, or specified repo name if provided, and include
			    them into the NEW_RPMS area that will be created beside
			    the ardana-dev-tools clone. Repeat as many times as
			    needed to add all projects and/or packages desired.)
    --ibs-repo PRJ         (Add specified IBS project's repo to the SLES nodes in
                            the cloud deployed by the astack.sh run.)
    --obs-repo PRJ         (Add specified OBS project's repo to the SLES nodes in
                            the cloud deployed by the astack.sh run.)
    --ipv4 NET-INDICES     (Specify comma sepatared list of net interface indices
                            in [0..8] e.g. 0,1,3,5 to indicate that these will
                            need an IPv4 address.)
    --ipv6 NET-INDICES     (Specify comma sepatared list of net interface indices
                            in [0..8] e.g. 0,1,3,5 to indicate that these will
                            need an IPv6 address.)
    --ipv6-all             (All net interfaces will need an IPv6 address.)

## Cloud Input Model Management

The cloud name specified via the `astack.sh` command line identifes which
Ardana CI input model you want `astack.sh` to use when creating a set of
nodes on which to deploy an Ardana cloud.

This model must be located in one of:
* `ardana/ardana-input-model.git` repo, under `2.0/ardana-ci`
* `ardana/ardana-dev-tools.git` repo itself under the
`ardana-vagrant-models/<cloud>-vagrant/input-model` directory.

For any models not located within the ardana-dev-tools repo the astack.sh
command will stage the version from the ardana-input-model repo under the
`ardana-vagrant-models/<cloud>-vagrant/input-model` directory using the
`bin/setup-vagrant-input-model` script.

### Input model specified hardware config

The traditional `ardana-input-model` style of input models relied on a
mapping of the role name associated with the servers in the `servers.yml`
file specified in the input model to a set of hash lookup tables at the
top of the `lib/ardana_vagrant_helper.rb` file.

For example if you wanted to increase the memory or cpus of the
controller node in the `demo` input model, which is associated with
the `LITE-CONTROLLER-ROLE` role, you would need to modify the entry
in the `lib/ardana_vagrant_helper.rb` `VM_MEMORY` or `VM_CPU` tables
for the LITECONTROL_NODE to the desired values.

However since the same role names may be used by multiple models, e.g.
`deployerincloude-lite` uses the same node role names as `demo`, such
changes, if made permanently, may have side effects.

However it is now possible to specify role specific hardware config
settings in the input model `servers.yml` file, in a `ci_settings`
section, keyed by the name of the role specified in that `servers.yml`
file.

#### The ci_settings hardware config

You can specify the following information for each unique role within a
model in the `ci_settings` section of the servers.yml file:

* `memory` - the amount of RAM, in MiB, to allocate for a Vagrant VM
* `cpus` - the number of vCPUs to allocate to a Vagrant VM
* `flavor` - the instance flavour to use for these nodes
* `disks` - settings related to attached disks
* * `boot` - boot disk settings
* * * `size_gib` - size in GiB of the boot disk
* * `extras` - additional disks settings
* * * `count` - number of extra disks to attach
* * * `size_gib` - size in GiB of each extra disk

See the adt model's [servers.yml](ardana-vagrant-models/adt-vagrant/input-model/data/servers.yml)
for an example.

### Customising locally staged input models
When you run astack.sh for the first time for a given cloud model, it will
use the `bin/setup-vagrant-input-model` script to stage the input model for
the specified cloud under `ardana-vagrant-models/<cloud>-vagrant/input-model`
for you, and then re-use that staged model until you either delete it, or
forcibly updating it using `--force` with the `setup-vagrant-input-model`
script.

This means that you can customise the input model, after it has been staged
locally within your ardana-dev-tools clone, and use it to (re-)deploy your
cloud.

## Pulling updated RPMs into your deployment

The default astack.sh deployment, if you have just cloned ardana-dev-tools,
will just use the appropriate SLES and Cloud repos based upon the specified
cloud version you are deploying, which defaults to Cloud9.

If you want to pull in addition changes to test as part of your deployment
you have a number of options:

* Clone relevant Ardana ansible or tool repos beside your ardana-dev-tools.
* Use the --ibs-prj & --obs-prj options to download RPMs from specified
  IBS or OBS projects to be included in the deployment. These options can
  be repeated to specify as many projects (or packages withing projects)
  as desired.
* Use the --ibs-repo & --obs-repo options to specify IBS & OBS repos that
  will be added to the SLES nodes within a deployment. These options can
  be repeated to specify as many projects as desired.

The first two mechanisms (cloning additional repos beside ardana-dev-tools
and using the --ibs-prj & --obs-prj options) rely on the fact that we will
create a special "Cloud Overrides" zypper repo on the deployer node that
will contain all of the RPMs published in the `NEW_RPMS` directory found
beside the ardana-dev-tools clone. Additionally this special repo will be
configured with priority 98, meaning it will be preferred as the source
for packages being installed.

### Cloning additional Ardana git repos beside ardana-dev-tools
If you clone additional repos beside ardana-dev-tools, e.g. ardana-input-model
or cinder-ansible, then when you kick off an astack.sh run, one of the first
things that will happen is that the `bin/update_rpms.sh` script will be run
which will attempt to build an updated version of the associated IBS RPM for
that Ardana git repo's commited branch, if it is one that we have packaged as
an RPM. If it succeeds the RPM that has been built will be published in the
`NEW_RPMS` directory beside the ardana-dev-tools clone.

NOTES:
* You must commit any pending changes to the branch for these changes to
  be built into the RPM; uncommitted changes will not be packaged in the RPM.
* The additional cloned repos must be checked out on branch derived from the
  appropriate branch for the Cloud version you are deploying for, e.g. for
  a Cloud8 deployment, the stable/pike branch should be the base branch for
  any branches you have checked out.

You can disable this mechanism by specifying the --no-update-rpms option
when running the astack.sh command.

### Pulling in RPMs from IBS & OBS projects
If you use the --ibs-prj or --obs-prj options you can specify the project,
or even a package with a project, whose RPMs will be downloaded and added
to the `NEW_RPMS` area.

For example, if you have built a modified version of an Ardana Rocky Venv
package, venv-openstack-keystone, under a branch in your OBS home project,
home:jblogs:branches:Cloud:OpenStack:Rocky:venv, you would run astack.sh
like so:

    % ardana-dev-tools/bin/astack.sh \
        --obs-prj home:jblogs:branches:Cloud:OpenStack:Rocky:venv \
	demo

However this will pull in all the RPMs from the specified project so if
you have more than one customised venv package under development in
home:jblogs:branches:Cloud:OpenStack:Rocky:venv, and you want to pull in
just the RPMs for the Keystone venv package, you would run astack.sh like
so:

    % ardana-dev-tools/bin/astack.sh \
        --obs-prj home:jblogs:branches:Cloud:OpenStack:Rocky:venv/venv-openstack-keystone \
	demo

Or if you want to test just two specific packages from your home branch,
e.g. the Keystone and Nova venv packages, and not any others, you can
specify both explicitly, like so:

    % ardana-dev-tools/bin/astack.sh \
        --obs-prj home:jblogs:branches:Cloud:OpenStack:Rocky:venv/venv-openstack-keystone \
        --obs-prj home:jblogs:branches:Cloud:OpenStack:Rocky:venv/venv-openstack-nova \
	demo

Finally you can mix both IBS and OBS projects and packages in the same run, e.g.

    % ardana-dev-tools/bin/astack.sh \
        --ibs-prj home:jblogs:branches:Devel:Cloud:9:Staging/ardana-ansible \
        --obs-prj home:jblogs:branches:Cloud:OpenStack:Rocky:venv/venv-openstack-keystone \
        --obs-prj home:jblogs:branches:Cloud:OpenStack:Rocky:venv/venv-openstack-nova \
	demo

### Adding IBS & OBS repos to SLES nodes
Using the --ibs-repo & --obs-repo you can specify IBS & OBS projects whose repos
will be added to the SLES nodes in a cloud deployment.

NOTES:
  * The IBS & OBS project repos must have enabled package publishing otherwise
no repo will be created, so if you have created a branch of a package under the
one of the Devel:Cloud:... projects, you will need to explicitly enabled this
mechanism, as it is may be disabled.
  * This option can result in slow deployment times if you are talking to the
respective build service over a slow, e.g. VPN, link.

## Useful tools

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

#### .astack_env

This is a dump of the environment setting that were active when the cloud
was being deployed, which can be sourced to setup the same environment
if you wish to run additional commands against the same cloud.

#### ardana-vagrant

This is a simple wrapper script that leverages the .astack_env file to
setup the environment appropriately and then runs the vagrant command
against the cloud, e.g.

    % ./ardana-vagrant ssh controller

#### ardana-vagrant-ansible

This is a simple wrapper script that leverages the .astack_env file
to setup the environment appropriately and then runs ansible-playbook
command against the cloud, e.g.

    % ./ardana-vagrant-ansible ../../ansible/cloud-setup.yml

If no arguments are specified it will run the cloud-setup.yml playbook
against the cloud; if you don't want to run the ardana-init command
again, you can specify the --skip-ardana-init option.

## Deploying manually

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

### Installing SUSE ROOT CA
Ensure that you have the SUSE ROOT CA installed as detailed at
[SUSE ROOT CA Installation](http://ca.suse.de)

### Installing Ansible
You can install install ansible locally on your system, but be warned
that it is unlikely that it will be a _fully Ardana compatible_ version
as most modern distros will install a newer version of ansible that we
have optimised Ardana for, which may see issues.

For best results we recommend running the ansible-dev-tools playbooks
using Ansible version 2.4.6. This can be done using a Python virtualenv
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

You will now be able to build a SLES vagrant image for use in booting the test
infrastructure.

    % env ARDANA_SLES_ARTIFACTS=true \
        bin/build-distro-artifacts

NOTE: This script ensure the latest versions of any artifacts are downloaded.

### Create the Cloud without deploying it

Now that we have a Vagrant box image, we bring up the target cloud, e.g. demo,
without deploying it, by running:

    % bin/astack.sh --no-artifacts --no-config --no-site demo

#### Other possible clouds

The development environment provides a set of cloud definitions that can be used:

* minimal: Cloud in a box

    A minimal single node cloud running a reduced number of services, disabling some of the Metering, Monitoring & Logging (MML) stack using a "hack"

* demo: A 2 node basic cloud

    A 2 node cloud with no MML stack. First node is a single node cloud control plane running only Keystone, Swift, Glance, Cinder, Neutron, Nova, Horizon and Tempest Openstack services, while the second node is a minimally sized compute node.
    A good starting choice if you don't have a lot of memory.

* deployerincloud: A 3 node cloud

    Cloud Control Plane (1 node: ha-proxy, Apache, MySQL, RabbitMQ, Keystone, Glance, Horizon, Nova, Neutron ) + 2 Compute Nodes, with deployer on controller node. Uses a simplified Swift ring model with EC disabled.

* deployerincloud-lite: A 3 node cloud

    A cutdown version of deployerincloud using same "hack" as minimal to disable some of the MML stack.
    Not recommended for anything other than playing with ardana-dev-tools.

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

* dac-3cp: A 4 node single region cloud

    A cutdown version of standard cloud with 2 computes removed and deployer at first controller (dac).

* std-split: A 5 node single region multi-control plane cloud

    Based on the standard cloud with 2 compute removed, using 3 single node control planes, 1 for core openstack services, 1 for DB & RabbitMQ, and 1 for MML stack, though Swift services are shared among all 3 to allow for a complete Swift ring model with EC disabled. Control node sizing are minimised to match running service requirements.

* mid-size: A multi-control plane, multi region cloud

* multi-cp: A more complex multi-control plane multi-region cloud

* adt: 2 node ardana-dev-tools validation testing cloud

    Extremely mininal cloud (keystone, horizon, tempest OpenStack services only) derived from the `demo` model, with a controller that is also a deployer, and one additional resource node that is available for re-imaging with run-cobbler.

WARNING : The mid-size & multi-cp models may not be stable/functional right now.

Each variant has its own vagrant definition, under the ardana-vagrant-models directory, and associated cloud model defined in the ardana-input-model repo, under the 2.0/ardana-ci directory.

### Logging in to the cloud

After the `astack.sh ...` has completed you will have a number of booted VMs,
with the appropriate SOC/CLM version installed on the deployer VM, and the
specified cloud model setup as your ~/openstack/my_cloud/definition.

You can log in to the nodes by cd'ing to ardana-vagrant-models/<cloud>-model
directory and then run the ardana-vagrant helper script in there to ssh into
a node, e.g to ssh to a node called deployer run.

    % ./ardana-vagrant ssh deployer

Alternatively you can use the astack-ssh-config file with the ssh command. e.g.

    % ssh -F astack-ssh-config deployer

NOTE: For some models, the deployer node may be controller, controller1 or
something like that, if it located on a controller node.

### Running the Configuration Processor

To run the configuration processor, you need to cd to the ardana/ansible
directory under the ~/openstack directory:

    % cd ~/openstack/ardana/ansible/

We have modified the config-processor-run.yml playbook to turn on CP encryption of
its persistent state and Ansible output.  If you run the playbook as follows:

    % ansible-playbook -i hosts/localhost config-processor-run.yml

You will be prompted for an encryption key, and also asked if you want to change the
encryption key to a new value, and it must be a different key.  You can
turn off encryption by typing the following:

    % ansible-playbook -i hosts/localhost config-processor-run.yml -e encrypt="" \
                     -e rekey=""

To run playbooks against the CP output:

    % ansible-playbook -i hosts/localhost ready-deployment.yml
    % cd ~/scratch/ansible/next/ardana/ansible

If you've turned-off encryption, type the following:

    % ansible-playbook -i hosts/verb_hosts site.yml

If you enabled encryption, type the following:

    % ansible-playbook -i hosts/verb_hosts site.yml --ask-vault-pass

Enter the encryption key that you used with the config processor run when prompted
for the Vault password.

In a baremetal re-install case, you'll need to wipe partition data on non-os disks to
allow osconfig to complete successfully.

If you wish to wipe all previously used non OS disks run the following before site.yml:

    % ansible-playbook -i hosts/verb_hosts wipe_disks.yml

This will require user confirmation during the run. This play will
fail if osconfig has previously been run.

To restrict memory usage below default 2g by elasticsearch you can pass lower amount.
Minimum value is 256m and it should allow operation for few hours at least. If you
plan system to run for longer period please use larger values.

    % ansible-playbook -i hosts/verb_hosts site.yml -e elasticsearch_heap_size=256m

For more information on the directory structure see TODO Add new link if possible [here].

Once the system is deployed and services are started, some services can be
populated with an optional set of defaults.

    % ansible-playbook -i hosts/verb_hosts ardana-cloud-configure.yml

If you are running behind a proxy, you'll need to set the proxy variable as
we download a cirros image during the cloud configure

    % ansible-playbook -i hosts/verb_hosts ardana-cloud-configure.yml \
                       -e proxy="http://<proxy>:<proxy_port>"

For now this:

* Downloads a cirros image from the Internet and uploads to Glance.

* Creates an external network - 172.31.0.0/16 is the default CIDR.
  You can over-ride this default by providing a parameter at run time:

    % ansible-playbook -i hosts/verb_hosts ardana-cloud-configure.yml \
                       -e EXT_NET_CIDR=192.168.99.0/24

Other configuration items are likely to be added in time, including additional
Glance images, Nova flavors and Cinder volume types.

## Configuration jinja2 templates
Configuration jinja2 templates, which are customer editable, are included in
`openstack/my_cloud/config`.

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
The use of Vagrant in Ardana is to create a virtual test environment, by setting up
a minimal installation on the Resource and Control Plane servers and to fully prep
the deployer server such that it is ready to start deploying to the Resource and
Control Plane servers.

## Using Ansible
Ansible performs all of the configuration of the deployer and of the resource and
control plane servers.  For use in the developer environment it is recommended that
you use the following to prevent ssh host key errors:

```
export ANSIBLE_HOST_KEY_CHECKING=False
```

All of the building and provisioning is controlled by ansible, and as such the use of
ansible variables can change both what and how things are built.  They can be
specified on the command line directly with the use of `-e <var>=<value>` or they can
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

## Building custom/updated RPM packages to modify you deployed cluster
When you run the `astack.sh` command, unless you have specified the
`--no-update-rpms` option as one of the options, the `bin/update_rpms.sh`
script will run which will check for an Ardana repos cloned beside the
ardana-dev-tools.git repo clone, and if any are found, it will build the
associated RPM, using the content of the cloned repo's active branch as
the sources.

NOTE: If you want to rebuild the RPM package form the ardana-ansible.git
repo, you need to also clone the ardana.git repo as well.

The built RPMs are saved to a `NEW_RPMS` yum repo, located beside your
`ardana-dev-tools`.

NOTE: The `NEW_RPMs` area will be wiped and recreated each time the
`update_rpms.sh` script is run, so if you already have run `astack.sh`
and are happy with the built RPMs, use the `--no-update-rpms` option
to skip rebuilding the RPMs and re-use the existing ones.

The contents of the NEW_RPMS area are automatically synchronised to
the deployer node when the Vagrant cloud is created, to form the
"Local Overrides" zypper repo, which is configured with a slightly
higher priority than the normal repos so that it is preferred as a
source for packages.

## Troubleshooting
Sometimes things go wrong.  Known issues are listed in [troubleshooting](doc/troubleshooting.md)

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
