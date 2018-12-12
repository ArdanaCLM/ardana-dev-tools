#!/bin/bash -e
#
# Copyright (c) 2010-2012 Patrick Debois
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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

aib_logs=/root/ardana_image_build
aib_script=vagrant
mkdir -p ${aib_logs}
exec 1>> ${aib_logs}/${aib_script}.log
exec 2>> ${aib_logs}/${aib_script}.log

# Vagrant specific settings

# Note that we have an ardana specific version of this in ardana.sh
#echo "[Saving vagrant image build timestamp]"
#date > /etc/vagrant_box_build_time

# Note that we have an ardana specific version of this in ardana.sh
# Customize the message of the day
#echo 'Welcome to your Vagrant-built virtual machine.' > /etc/motd


# Determine user account we will be setting up for use with Vagrant
[[ -z "${VAGRANT_USER}" ]] && VAGRANT_USER="vagrant"
[[ -z "${HOME_BASE}" ]] && HOME_BASE="/home"
home_dir="${HOME_BASE}/${VAGRANT_USER}"
echo "[Using '${VAGRANT_USER}' under '${HOME_BASE}']"

# if the user exists, presume we've created them some other way
# with the correct levels of access.
if ! id -u ${VAGRANT_USER} >/dev/null 2>&1
then
    echo "[Creating '${VAGRANT_USER}' under '${HOME_BASE}']"
    # Add vagrant user
    /usr/sbin/groupadd "${VAGRANT_USER}"
    /usr/sbin/useradd "${VAGRANT_USER}" -d "${home_dir}" -g "${VAGRANT_USER}" -m -G users

    # Initial password is the username
    echo "${VAGRANT_USER}:${VAGRANT_USER}" | chpasswd

    # Set up passwordless sudo priviledges
    echo "${VAGRANT_USER} ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/${VAGRANT_USER}"
    chmod 0440 "/etc/sudoers.d/${VAGRANT_USER}"
fi

# create a symlink from /home/$VAGRANT_USER to real home dir, if not under /home
# some tooling still explicitly references /home/${VAGRANT_USER}
home_link="/home/${VAGRANT_USER}"
if [[ "${home_link}" != "${home_dir}" ]]
then
    echo "[Creating '/home/${VAGRANT_USER}' symlink]"
    [[ -e "${home_link}" ]] || ln -s "${home_dir}" "${home_link}"
fi

# Installing vagrant keys
echo "[Setup INSECURE initial Vagrant key to enable Vagrant ssh key setup]"
mkdir -pm 700 "${home_dir}/.ssh"
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O "${home_dir}/.ssh/authorized_keys"
chmod 0600 "${home_dir}/.ssh/authorized_keys"
chown -R "${VAGRANT_USER}" "${home_dir}/.ssh"
chmod 0700 "${home_dir}"

# vim:shiftwidth=4:tabstop=4:expandtab
