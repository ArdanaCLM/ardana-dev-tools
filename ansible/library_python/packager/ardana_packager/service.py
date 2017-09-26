#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
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
"""
Given an expanded package, link it into a service-component.

The package already exists in the package directory.

Scheme: there's a base path,
  /opt/stack/venv

Underneath this there are the 'installed packages' - these are directories
with names like
  /opt/stack/venv/nova-20150101T010203Z

There's a service-component base path,
  /opt/stack/service

Underneath this there are the 'installed service components' - these are
symlinks with names like
  /opt/stack/service/nova-api

These link to a versioned directory

  /opt/stack/service/nova-api -> nova-api-20150101T010203Z

That location includes the version currently activated.

That directory is laid out as follows:

  /opt/stack/service/nova-api-20150101T010203Z/
     venv -> /opt/stack/venv/nova-20150101T010203Z
     etc/    The versioned configuration directory

"""

import os
import os.path
import shutil

from ardana_packager.activate import active_version, ensure_suffix  # noqa
from ardana_packager.error import InstallerError
import ardana_packager.expand as expand


_VENV_DIR = "venv"
_ETC_DIR = "etc"


def service_pointer(config, spec):
    return os.path.join(config.SERVICE_LOCATION, spec.service)


def service_dir(config, spec):
    return os.path.join(config.SERVICE_LOCATION,
                        spec.service + "-" + spec.suffix)


def refer(conf, spec):
    """Take the package installed in venv_dir and refer to it.

    Returns True if it modified the filesystem.
    """

    package_dir = expand.package_dir(conf, spec)
    target_dir = service_dir(conf, spec)

    if not os.path.isdir(package_dir):
        raise InstallerError(
            "{package_dir} not found"
            .format(package_dir=package_dir))

    if os.path.isdir(target_dir):
        # We assume there's nothing to do
        return False

    if os.path.exists(target_dir):
        raise InstallerError(
            "{target_dir} already exists"
            .format(target_dir=target_dir))

    try:
        os.mkdir(target_dir, 0o755)
        os.symlink(package_dir, os.path.join(target_dir, _VENV_DIR))
        os.mkdir(os.path.join(target_dir, _ETC_DIR), 0o755)

    except Exception as e:
        raise InstallerError(
            "{package_dir} could not be installed as {target_dir}"
            .format(package_dir=package_dir, target_dir=target_dir), e)

    return True


def remove(config, spec):
    """Remove an exploded version

    This is an error if the version's currently activated.
    There's no error if the version is already not there.

    Returns True if it modified the filesystem
    """

    location = service_pointer(config, spec)
    current_version = active_version(config.SERVICE_LOCATION, spec)
    if current_version == spec.version:
        raise InstallerError(
            "Cannot remove {version} for {location} since it is current active"
            .format(location=location, version=spec.version))

    ensure_suffix(config.SERVICE_LOCATION, spec)
    target = service_dir(config, spec)

    if not os.path.exists(target):
        return False

    if not os.path.isdir(target):
        msg = ("Cannot remove {version} for {location} since it is not"
               " a directory".format(location=location, version=spec.version))
        raise InstallerError(msg)

    try:
        # Delete recursively
        shutil.rmtree(target)
    except Exception as e:
        raise InstallerError(
            "Could not delete {target}"
            .format(target=target), e)

    return True


def count_refs(conf, spec):
    """Return the versioned service names that refer to this package

    We look through any subdirectories of the service directory, searching
    for venv symlinks that point to the specified package.
    """

    dirs = []

    target = expand.package_dir(conf, spec)

    for file in os.listdir(conf.SERVICE_LOCATION):
        topdir = os.path.join(conf.SERVICE_LOCATION, file)
        if not os.path.isdir(topdir):
            continue

        venv = os.path.join(topdir, _VENV_DIR)
        if not os.path.islink(venv):
            continue

        if os.readlink(venv) == target:
            dirs.append(file)

    return dirs
