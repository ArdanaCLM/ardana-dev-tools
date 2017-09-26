#!/bin/bash -e
#
# Copyright (c) 2010-2012 Patrick Debois
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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

# Vagrant specific
#date > /etc/vagrant_box_build_time

[[ -z "${VAGRANT_USER}" ]] && VAGRANT_USER=vagrant

# if the user exists, presume we've created them some other way
# with the correct levels of access.
id -u ${VAGRANT_USER} >/dev/null 2>&1
if [[ $? -ne 0 ]];
then
    # Add vagrant user
    /usr/sbin/groupadd ${VAGRANT_USER}
    /usr/sbin/useradd ${VAGRANT_USER} -g ${VAGRANT_USER} -G wheel
    echo "${VAGRANT_USER}"|passwd --stdin ${VAGRANT_USER}
    echo "${VAGRANT_USER}        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/${VAGRANT_USER}
    chmod 0440 /etc/sudoers.d/${VAGRANT_USER}
fi

# Installing vagrant keys
mkdir -pm 700 /home/${VAGRANT_USER}/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O /home/${VAGRANT_USER}/.ssh/authorized_keys
chmod 0600 /home/${VAGRANT_USER}/.ssh/authorized_keys
chown -R ${VAGRANT_USER} /home/${VAGRANT_USER}/.ssh
chmod 0700 /home/${VAGRANT_USER}

# Customize the message of the day
#echo 'Welcome to your Vagrant-built virtual machine.' > /etc/motd
