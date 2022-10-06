#
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
#
"""
Expand a package prior to installation

The package already exists in a cache somewhere.
Expand it to its target location.

Scheme: there's a base path,
  /opt/stack/venvs

Underneath this there are the 'installed packages' - these are symlinks
with names like
  /opt/stack/venvs/nova

Those symlinks link to a relative location:

  /opt/stack/venvs/nova -> nova-20150101T010203Z

That location includes the version currently activated.

We are targeting the destination directories,

  /opt/stack/venvs/nova-20150101T010203Z

with the contents of an exploded tarfile, whose contents are expanded
*relative to that directory*.
"""

import grp
import os
import os.path
import shutil
import tarfile

from ardana_packager.activate import active_version
import ardana_packager.cache as cache
from ardana_packager.error import InstallerError


def package_dir(config, spec):
    return os.path.join(config.VENV_LOCATION, spec.package + "-" + spec.suffix)


def explode(config, spec):
    """Take the package installed in cache_dir and expand it.

    This will be a no-op if there's already something
    at the target.

    We require the source package to be present in
    the cache_dir, with the name
    $(basename $location)-suffix.tgz

    Returns (True, spec) if it modified the filesystem.
    """

    spec = cache.assert_package_present(config, spec)
    cache_file = cache.cache_file(config, spec)
    target_dir = package_dir(config, spec)

    if not os.path.isfile(cache_file):
        raise InstallerError(
            "{cache_file} not found"
            .format(cache_file=cache_file))

    if not tarfile.is_tarfile(cache_file):
        raise InstallerError(
            "{cache_file} is not in the correct format"
            .format(cache_file=cache_file))

    if os.path.isdir(target_dir):
        # We assume there's nothing to do
        return (False, spec)

    if os.path.exists(target_dir):
        raise InstallerError(
            "{target_dir} already exists"
            .format(target_dir=target_dir))

    try:
        os.mkdir(target_dir, 0o755)

        gname = config['group_name']
        group = grp.getgrnam(gname)
        gid = group.gr_gid

        with tarfile.open(cache_file) as tar:
            members = tar.getmembers()
            for m in members:
                m.uid = 0
                m.gid = gid
                m.uname = 'root'
                m.gname = gname
                m.mode |= config['extra_mode_bits']
            def is_within_directory(directory, target):

                abs_directory = os.path.abspath(directory)
                abs_target = os.path.abspath(target)

                prefix = os.path.commonprefix([abs_directory, abs_target])

                return prefix == abs_directory

            def safe_extract(tar, path=".", members=None, *, numeric_owner=False):

                for member in tar.getmembers():
                    member_path = os.path.join(path, member.name)
                    if not is_within_directory(path, member_path):
                        raise Exception("Attempted Path Traversal in Tar File")

                tar.extractall(path, members, numeric_owner=numeric_owner)


            safe_extract(tar, path=target_dir, members=members)

    except Exception as e:
        raise InstallerError(
            "{cache_file} could not be exploded to {target_dir}"
            .format(cache_file=cache_file, target_dir=target_dir), e)

    return (True, spec)


def remove(config, spec):
    """Remove an exploded version

    This is an error if the version's currently activated.
    There's no error if the version is already not there.

    Returns True if it modified the filesystem
    """

    location = os.path.join(config.VENV_LOCATION, spec.package)
    current_version = active_version(config.VENV_LOCATION, spec)
    if current_version == spec.version:
        raise InstallerError(
            "Cannot remove {version} for {location} since it is current active"
            .format(location=location, version=spec.version))

    target = location + "-" + spec.suffix

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
