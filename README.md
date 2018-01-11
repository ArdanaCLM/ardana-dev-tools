#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
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

This repo contains all of the tools needed to develop for Ardana.

This is a developer environment that uses [Vagrant](https://docs.vagrantup.com/v2/why-vagrant/)
to create a test environment and then runs the Ardana code to configure that test environment.
All of the configuration is done through [Ansible](http://docs.ansible.com/).

This document contains a getting-started guide for the Ardana developer environment.
The remainder of the documentation related to Ardana is located in the top-level doc
dir on this repo. Key documentation items are:

- [Developer workflow](doc/dev-workflow.md): When you have the environment
up and running,  this provides details on the general Ardana developer workflow
for testing changes in different parts of the Ardana Openstack release.
- [Trouble-shooting](doc/troubleshooting.md): For known issues and workarounds.
- [Ardana Ansible Guide](doc/ardana-ansible-guide/ardana-ansible-guide.md): A set of docs
providing instructions on the writing of Ansible code for services, including a
full description of the layout of a service Ansible repo.

## Things to be aware of when getting started

To bring up a few important issues you should be aware of.

### Vagrant version

The Ardana OpenStack CI infrastructure uses Vagrant 1.7.2; however in early
2017 HashiCorp stopped providing a Ruby Gems mirror at gems.hashicorp.com, and
as a result Vagrant 1.7.2 is unable to build plugins anymore. However we can
use Vagrant 1.7.4 to build compatible plugins and then downgrade to Vagrant
1.7.2 again. This is handled automatically by the dev-env-install.yml
playbook.

NOTE: If you want to avoid this upgrade/downgrade of vagrant, you can set
ARDANA_DEVELOPER=1 (or true) in your environment, and Vagrant 1.7.4 will be used.
Additionally if you need to run a newer version of Vagrant on your system for
other reasons you can additionally set ARDANA_VAGRANT_VERSION to the desired
version in your environment. You may need to delete ~/.vagrant.d after doing
so to ensure you plugins are built with the correct version of Vagrant.

For example

    export ARDANA_DEVELOPER=true
    export ARDANA_VAGRANT_VERSION=1.8.7

### Ansible version

The Ardana OpenStack ansible playbooks, especially those in
ardana/ardana-dev-tools.git, have not been updated to work with Ansible 2.x,
and will only work with Ansible 1.9.

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

## Run Ardana Stack

Before trying to run another cloud deployment, run the cleanup script located
at bin/cleanup-slave. This will clean everything and allow it to rebuild the
networks again. Warning that the cleanup-slave is quite destructive and if
there are other vagrant libvirt VM's running on the system it will remove them
all.

This script enables you to set up Ardana:

    ./bin/astack.sh dac-min

The cloud defaults to dac-min. You can specify the cloud configuration to
be used as the last argument on the command line e.g. ./astack.sh std-min

Add the following parameters for more options:

    --no-setup             (Don't run dev-env-install.yml)
    --no-build             (Don't build venvs, reuse existing packages)
    --no-config            (Don't automatically compile the cloud model and
                            prepare the scratch area after previsioning cloud;
                            implies --no-site)
    --no-site              (Don't run the site.yml play after previsioning cloud)
    --run-tests            (Run the tests against cloud after a successful test)
    --tarball TARBALL      (Specify a prebuilt deployer tarball to use)
    --ci                   (Sets the same options for running in the CI CDL lab)
    --guest-images         (Builds and uploads guest images to glance)
    --rhel                 (Builds RHEL artifacts for inclusion in product tarball)
    --rhel-compute         (Configures compute nodes to be RHEL based)

## Getting Started

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
The first part of the setup is to install ansible as follows:

On openSUSE Leap 42.2:

   sudo zypper in ansible

On Ubuntu 14.04 and 16.04:

It is recommended to install Ansible in its own virtualenv.

1. sudo apt-get install virtualenv build-essential python-dev python-all libpython2.7-dev libssl-dev libffi-dev
2. mkdir ~/[your-venv-folder];
3. virtualenv ~/[your-venv-folder]/ansible
4. Activate the ansible venv with:
   . ~/[your-venv-folder]/ansible/bin/activate
5. pip install -r ardana-dev-tools/requirements.txt


### Local sites

If there is a local site defined with mirrors for Python and system packages then you
can set the ARDANA_SITE environment variable to specify your local site. The default
site is in Provo. Note that we do this automatically for all CI runs.

For example,

    export ARDANA_SITE=provo

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


### Download the hLinux ISO

The hLinux ISO is required for running the build and cloud nodes. It contains the
apt repositories we use for both building the venvs and deploying the cloud.

To the latest hLinux ISO in use, run the following on the command line:

    ansible-playbook -i hosts/localhost get-hlinux-iso.yml

This can take a while to run as the hLinux ISO is ~ 1.2 gigs in size. The temporary
download file is in /tmp if you want to watch it grow.  But if you rerun the
command it will recognize when you have a cached version and it won't try and
download it a second time.


### Build a hLinux Vagrant Image

You will now be able to build a hlinux vagrant image for use in building venvs and
booting the test infrastructure.

    ansible-playbook -i hosts/localhost image-build-vagrant-box.yml

By default the running of the ansible commands will result in ensuring that your
cloned repositories are up to date with the correct branch - usually `master`.
If you do not want it to update the repositories you can set the appropriate
variables to `False` or `no`.  This can be done on the command line as follows:

    ansible-playbook -i hosts/localhost image-build-vagrant-box.yml -e image_build_git_update=no


### Create the Deployer Appliance

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

    cd ../build-vagrant
    # to create virtual machines on the local system using libvirt
    export VAGRANT_DEFAULT_PROVIDER=libvirt
    vagrant up

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

    $ ls ~/ardana
    glance  ardana-dev-tools  nova

Now, the venvs can be built and packaged up using the build virtual machine.

    ansible-playbook -i ../ansible/hosts/vagrant.py ../ansible/venv-build.yml

This process should result in packaged venvs being created in the ardana-dev-tools/scratch
directory: these have names like `nova-{version}.tgz`. Those packages are used
in the following steps. (For more details on this process, and additional options,
see the [longer notes](build-vagrant/README.md).

If you are short of resources, you may choose to remove the build VM at this point :

    vagrant destroy

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

For example to get vagrant to create the VMs needed for a standard cloud with default node distro setting use the following command:

    cd ../ardana-vagrant-models/standard-vagrant
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

    ccn-0001                  running (libvirt)
    ccn-0002                  running (libvirt)
    ccn-0003                  running (libvirt)
    cpn-0001                  running (libvirt)
    cpn-0002                  running (libvirt)
    cpn-0003                  running (libvirt)
    deployer                  running (libvirt)

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

5. scp this new tgz up to the deployer directory at /opt/ardana_packager/openstack-<version>/hlinux_venv/.

6. vagrant ssh to the deployer and regenerate the packager index:
    sudo /opt/stack/service/packager/venv/bin/create_index --dir /opt/ardana_packager/openstack-<version>/hlinux_venv/

7. Verify your new package listed in packages:
    cat /opt/ardana_packager/openstack-<version>/hlinux_venv/packages

8. Do an upgrade of the service:
    ansible-playbook -i hosts/verb_hosts swift-upgrade.yml

## Troubleshooting
Sometimes things go wrong.  Known issues are listed in [troubleshooting](doc/troubleshooting.md)

## Emulating the CI Build & Testing Process
The CI Build and Test process can be more closely emulated by passing the
--ci option to the astack.sh script, e.g. ./astack.sh --ci standard
The primary impact of doing so will be that the user account on the vagrant 
VMs will be ardanauser rather than stack. Additionally when creating a standard 
cloud, the 3rd compute VM will be created as a RHEL7 rather than hLinux VM. 
See [doc/dev-workflow.md] for more details.
