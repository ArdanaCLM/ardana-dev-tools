
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


# Ardana Troubleshooting: known problems and workarounds

Sometimes things go wrong.  Here are some of the known issues that can occur and
how to work around or fix them:

## Ansible failures
There are a number of scenarios in which this can occur.  One of them is that the
ansible genuinely failed and so needs to be debugged further, but there are at
least 2 others where it is a vagrant bug and the command just needs to be rerun.

### Error Message:
```
An error occurred while executing the action on the 'cpn-2'
machine. Please handle this error then try again:

Ansible failed to complete successfully. Any error output should be
visible above. Please fix these errors and try again.
```

### Resolution:
If the status of the server from the `vagrant status` command is `running`, you can
re-run the `vagrant provision` command for the specific server that failed, e.g.:

```
vagrant provision cpn-2
```

### Alternative Resolution:
If the status of the server from the `vagrant status` command is `not created`, you
must re-run the `vagrant up` command for the specific server that failed, e.g.:

```
vagrant up cpn-2
```

## Volume for domain is already created. Please run 'vagrant destroy' first.
A libvirt volume was left behind and not cleaned up during a vagrant destroy operation.
The use of `virsh` can locate and remove the volume.

### Error Message:
```
An error occurred while executing the action on the 'ccn-1'
machine. Please handle this error then try again:

Volume for domain is already created. Please run 'vagrant destroy' first.
```

#### Resolution:
Locate the volume and then delete it.

1. Locate the volume

    ```
    virsh vol-list --pool=default
     Name                 Path
    ------------------------------------------------------------------------------
     hlinux_vagrant_box_image.img /var/lib/libvirt/images/hlinux_vagrant_box_image.img
     standard-vagrant_ccn-1.img /var/lib/libvirt/images/standard-vagrant_ccn-1.img
    ```
1. Delete the offending image:

    ```
    virsh vol-delete --pool=default standard-vagrant_ccn-1.img
    ```

#### Alternative Resolution:
If for any reason the first resolution fails, the following more severe solution should
work.

1. Locate the volume

    ```
    virsh vol-list --pool=default
     Name                 Path
    ------------------------------------------------------------------------------
     hlinux_vagrant_box_image.img /var/lib/libvirt/images/hlinux_vagrant_box_image.img
     standard-vagrant_ccn-1.img /var/lib/libvirt/images/standard-vagrant_ccn-1.img
    ```
1. Manually delete the image

    ```
    sudo rm -rf /var/lib/libvirt/images/standard-vagrant_ccn-1.img
    ```
1. Refresh the volume pool

    ```
    virsh pool-refresh default
    ```

### Error Message:
The following error may occur when running 'vagrant up' in the 'standard-vagrant' directory.
```
An error occurred while executing the action on the 'ccn-1'
machine. Please handle this error then try again:

Name `standard-vagrant_ccn-1` of domain about to create is already taken. Please try to run
`vagrant up` command again.
```

This can occur if you have a second development environment running under another path.

#### Resolution:
1. Run 'vagrant destroy' to remove any virtual machines that were created successfully.

    ```
    $ vagrant destroy
    ==> deployer: Removing domain...
    ==> cpn-3: Removing domain...
    ==> cpn-2: Removing domain...
    ==> cpn-1: Domain is not created. Please run `vagrant up` first.
    ==> ccn-3: Domain is not created. Please run `vagrant up` first.
    ==> ccn-2: Domain is not created. Please run `vagrant up` first.
    ==> ccn-1: Domain is not created. Please run `vagrant up` first.
    ```

2. Use virsh undefine to remove each virsh domain that was reported in an error message.

    ```
    $ virsh undefine standard-vagrant_ccn-1
    Domain standard-vagrant_ccn-1 has been undefined

    $ virsh undefine standard-vagrant_ccn-2
    Domain standard-vagrant_ccn-2 has been undefined

    $ virsh undefine standard-vagrant_ccn-3
    Domain standard-vagrant_ccn-3 has been undefined

    $ virsh undefine standard-vagrant_cpn-1
    Domain standard-vagrant_cpn-1 has been undefined
    ```

#### Alternative Resolution:
If you still get the following after performing the above resolution:
    ```
    Name `standard-vagrant_ccn-1` of domain about to create is already taken. Please try to run
    `vagrant up` command again.
    ```

1. Check that the machine definition file does not still exists after the destroy by doing a

    ```
    virsh list --all

     Id    Name                           State
    ----------------------------------------------------
     -     build-vagrant_build            shut off
    ```

2. (Re)define the machine

    ```
    sudo virsh define /etc/libvirt/qemu/build-vagrant_build.xml
    Domain build-vagrant_build defined from /etc/libvirt/qemu/build-vagrant_build.xml
    ```

3. Check that it is still sane (of course you have another problem if it is not still sane ;)
    ```
    virsh list --all
     Id    Name                           State
    ----------------------------------------------------
     -     build-vagrant_build            shut off
    ```

4. Then undefine the machine using virsh to clean up
    ```
    virsh undefine build-vagrant_build
    Domain build-vagrant_build has been undefined

    rusty@rustyz640:/var/lib/libvirt/images$ virsh list --all
     Id    Name                           State
    ----------------------------------------------------
    ```

5. And you can then go on about your 'vagrant up' steps successfully



### Error Message:
The following error may occur on a *first* run of ardana-deploy.yml due to a race in the keystone playbook

TASK: [Create Admin Tenant]
failed: [STANDARDBASE-CCP-T1-M1-NETCLM] => {"failed": true}
msg: exception: Unable to establish connection to http://STANDARDBASE-CCP-T01-VIP-KEY-API-NETCLM:35357/v2.0/tenants

FATAL: all hosts have already failed -- aborting

#### Resolution:
Just rerun the deploy - this is a race conditioon on keystone startup:
    ansible-playbook -i hosts/verb_hosts ardana-deploy.yml



### Error Message:
dev-env-install.yml fails on ubuntu 15.04 with
```
ERROR: Failed to build gem native extension. (Gem::Installer::ExtensionBuildError)
```

Or when installing the plugin directly

```
Makefile:223: recipe for target 'domain.o' failed
make: *** [domain.o] Error
```

#### Resolution
This seems to be an incompatibility between vagrant and the version of libvirt on 15.04
See here for details https://github.com/pradels/vagrant-libvirt/issues/346

Can be fixed by running the follwoing command as root:
ln -fs /usr/bin/ld.gold /usr/bin/ld

After completing libvirt installation you can revert this by using command:
```
sudo ln -fs /usr/bin/ld.bfd /usr/bin/ld
```

Leaving it pointing to ld.gold seems to work fine on a system dedicated to
running the Ardana Dev envrionment, not clear if / how this would affect other
uses of the system



## Modifying the default settings

### Using a different number of nodes

You need to change the number of nodes in two places.
1. In Vagrantfile in the standard-vagrant directory.
2. In the ardana-dev-tools/deployer-repos/ardana-configuration-processor/Data/Cloud/standard/cloudConfig.json

These 2 files need to be compatible.

### Vagrant is attempting to interface with the UI in a way that requires a TTY

#### Error Message:
```
Vagrant is attempting to interface with the UI in a way that requires
a TTY. Most actions in Vagrant that require a TTY have configuration
switches to disable this requirement. Please do that or run Vagrant
with TTY.
```
#### Resolution:
Although not the only source of this issue, this could mean that you have
a prior install of vagrant on your workstation. This can be resolved by
uninstalling vagrant and allowing it to be installed by the dev environment
install playbook. This ensures that the correct version of Vagrant is
installed for the Ardana developer environment:

1. Uninstall the existing vagrant package, e.g.:
```
sudo apt-get purge vagrant
```
1. Change to the ansible dir in ardana-dev-tools repo.
1. Run the following playbook step:

```
ansible-playbook -i hosts/localhost dev-env-install.yml
```

### To Install Ansible in a python virtual environment:

#### Resolution:

1. sudo apt install virtualenv
2. mkdir ~/[your-venv-folder];
3. virtualenv --python python2.7 ~/[your-venv-folder]/ansible
4. Activate the ansible venv with:
   . ~/[your-venv-folder]/ansible/bin/activate
5. pip install -r ardana-dev-tools/requirements.txt


### Attempting to install Ansible and run astack.sh on Ubuntu 16.04 fails.
When you run 'sudo gdebi -n ansible_1.9.4-1ppa~trusty_all.deb' it fails with:
  This package is uninstallable
  Dependency is not satisfiable: python-support (>= 0.90)

After installing Ansible in it's own virtual env, running astack.sh fails when
using the default /usr/bin/ld setting.

#### Resolution:
You will need to install Ansible in it's own virtual env and alter the
/usr/bin/ld to point to /usr/bin/ld.gold

You will need to install extra packages on Ubuntu 16.04 in order to successfully
install Ansible in it's own virtual env.
1. sudo apt-get install build-essential python-dev python-all libpython2.7-dev libssl-dev libffi-dev
2. sudo ln -fs /usr/bin/ld.gold /usr/bin/ld
   _N.B. Please refer to the section of this guide on dev-env-install.yml
   fails on ubuntu 15.04 due to gem native extension.
3. _N.B. Please refer to the section of this guide on how to install Ansible in
   it's own virtual env.

When running bin/astack.sh do so with the Ansible venv activated.
If you want to have ansible-playbook use this venv then do:
mkdir ~/bin
ln -s ~/[your-venv-folder]/ansible/bin/ansible-playbook ~/bin/
