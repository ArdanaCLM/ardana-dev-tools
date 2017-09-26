#
# (c) Copyright 2015 Hewlett Packard Enterprise Development LP
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
Install a package

The package already exists on the filesystem somewhere.
Install it to its target location.

If there's another packaged installed to the same place, deactivate it.

Scheme: there's a base path,
  /opt/stack/venvs

Underneath this there are the 'installed packages' - these are sylinks
with names like
  /opt/stack/venvs/nova

Those symlinks link to a relative location:

  /opt/stack/venvs/nova -> nova-2015-01-01-01-02-03

That location includes the version currently activated.
"""

import os
import os.path

from ardana_packager.config import DIR_FORMAT
from ardana_packager.error import InstallerError
from ardana_packager.version import from_service_dir


def active_version(base_location, spec):
    """Is there a package installed at the specified location?

        If so, return its version; otherwise None.
        If it looks like something's not right (eg, bad
        symlink or some other file there), throw an exception.
    """

    location = os.path.join(base_location, spec.service)
    try:
        if not os.path.exists(location):
            return None
        target = os.readlink(location)
        if not target.startswith(spec.service + "-"):
            raise InstallerError(
                "{location} is not an installed venv; target is {target}"
                .format(location=location, target=target))
        return from_service_dir(os.path.join(base_location, target))
    except OSError:
        raise InstallerError("{location} is not a symlink"
                             .format(location=location))


def activate(base_location, spec):
    """Symlink to an installed version

        Given the availability of some pre-installed version,
        create the appropriate symlink.
        Raise an error if the pre-installed version does not exist.
        Raise an error (note, do we want to do this?) if there's already
        something installed there.
    """

    location = os.path.join(base_location, spec.service)
    current_version = active_version(base_location, spec)
    if current_version is not None:
        raise InstallerError(
            "{location} already has an installed version: {version}"
            .format(location=location, version=current_version))

    spec = ensure_suffix(base_location, spec)
    target = spec.service + "-" + spec.suffix
    if not os.path.isdir(location + "-" + spec.suffix):
        raise InstallerError(
            "No pre-expanded version {version} for {location} found"
            .format(location=location, version=str(spec.version)))

    try:
        os.symlink(target, location)
    except OSError:
        raise InstallerError(
            "Cannot symlink {location} to {target}"
            .format(location=location, target=target))


def ensure_suffix(base_location, spec):
    try:
        if spec.suffix is not None:
            return spec
    except AttributeError:
        pass

    # Locate the appropriate suffix associated with this verison.
    for file_name in os.listdir(base_location):
        match = DIR_FORMAT.match(file_name)
        if not match:
            continue
        #if not file_name.startswith(spec.service + "-"):
        if spec.service != match.group(1):
            continue
        dir = os.path.join(base_location, file_name)
        if spec.version != from_service_dir(dir):
            continue
        spec.suffix = match.group(2)
        return spec

    raise InstallerError(
        "Cannot find version {version} for service {service}"
        .format(version=str(spec.version), service=spec.service))


def deactivate(base_location, spec):
    """Deactivate an installed version

        Given an installed version at the given location,
        deactivate it.
        If an explicit version is specified, then it is an error
        if any other version is present.
        Otherwise, we'll simply deactivate whatever is found
        there.
    """

    location = os.path.join(base_location, spec.service)
    current_version = active_version(base_location, spec)
    if spec.version is not None and current_version != spec.version:
        msg = ("Attempt to deinstall {version} from {location} -"
               " {current} found instead")
        raise InstallerError(msg
                             .format(location=location,
                                     version=str(spec.version),
                                     current=current_version))

    if os.path.islink(location):
        try:
            os.unlink(location)
        except IOError as e:
            raise InstallerError("Can't unlink {location}"
                                 .format(location=location), e)
