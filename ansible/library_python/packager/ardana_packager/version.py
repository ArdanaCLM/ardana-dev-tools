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
Management functions for handling versions.

We turn version strings into Version objects.
This includes a small static map of older version strings,
which map onto their corresponding new values.
"""

import os.path
import tarfile
import yaml

from ardana_packager.config import DIR_FORMAT, TAR_FORMAT, VERSION_LATEST  # noqa
from ardana_packager.error import InstallerError


class Version(object):
    def __init__(self, parts=None):
        if parts is None:
            parts = [[0]]

        self._parts = parts

    def __eq__(self, other):
        return other is not None and self._parts == other._parts

    def __ne__(self, other):
        return other is None or self._parts != other._parts

    def __le__(self, other):
        return self._parts <= other._parts

    def __lt__(self, other):
        return self._parts < other._parts

    def __ge__(self, other):
        return self._parts >= other._parts

    def __gt__(self, other):
        return self._parts > other._parts

    def __str__(self):
        return ':'.join('.'.join(str(n) for n in p) for p in self._parts)


def from_str(s):
    """Given a plain string version, return the Version object"""
    return Version(
        [[int(n) if n.isdigit() else n for n in p.split('.')]
         for p in s.split(':')])


with open(os.path.join(os.path.dirname(__file__), 'versions.yml')) as f:
    _BEST_GUESS = yaml.safe_load(f)


def best_guess(s):
    try:
        return _BEST_GUESS[s]
    except KeyError:
        if ":" in s:
            return s
        else:
            return "2.0.0:" + s


def from_tarball(fn):
    """Given a tarball path, extract Version from META-INF/version.yml.

        If that file does not exist, use your best guess from the
        suffix (which *must* work).
    """
    with tarfile.open(fn) as tf:
        version_file = os.path.join('.',
                                    'META-INF',
                                    'version.yml')
        try:
            f = tf.extractfile(version_file)
            if f is not None:
                version_metadata = yaml.safe_load(f)
                version_string = (str(version_metadata['version']) + ":" +
                                  str(version_metadata['timestamp']))
                if 'patch' in version_metadata:
                    version_string += ":" + str(version_metadata['patch'])
                return from_str(version_string)
        except KeyError:
            pass

    # Guess from the suffix
    return guess_from_suffix(fn, TAR_FORMAT)


def guess_from_suffix(file_name, format, group=2):
    """Return a best guess, given a directory or tarball name"""

    file = os.path.basename(file_name)
    match = format.match(file)
    if not match:
        raise InstallerError(
            "{} doesn't have a viable suffix".format(file_name))
    version = match.group(group)

    # The suffix is from an older ISO image
    guess = best_guess(version)
    if guess == version:
        raise InstallerError("{} has an unknown suffix".format(file_name))

    return from_str(guess)


def from_dir(dir):
    """Given a directory, look in dir/META-INF/version.yml.

        If that's not there, guess from the suffix.
    """

    version_file = os.path.join(dir, 'META-INF', 'version.yml')
    if os.path.exists(version_file):
        with open(version_file) as f:
            version_metadata = yaml.safe_load(f)
            version_string = (str(version_metadata['version']) + ":" +
                              str(version_metadata['timestamp']))
            if 'patch' in version_metadata:
                version_string += ":" + str(version_metadata['patch'])
            return from_str(version_string)

    # Guess from the suffix
    return guess_from_suffix(dir, DIR_FORMAT)


def from_service_dir(dir):
    """Given a directory, look in dir/venv/META-INF/version.yml.

        Otherwise, guess from the suffix.
    """

    version_file = os.path.join(dir, 'venv', 'META-INF', 'version.yml')
    if os.path.exists(version_file):
        with open(version_file) as f:
            version_metadata = yaml.safe_load(f)
            version_string = (str(version_metadata['version']) + ":" +
                              str(version_metadata['timestamp']))
            if 'patch' in version_metadata:
                version_string += ":" + str(version_metadata['patch'])
            return from_str(version_string)

    # Guess from the suffix
    return guess_from_suffix(dir, DIR_FORMAT)


class Spec(object):
    """Package and Service version specifier.

        A specifier: this is a potential four-tuple,
        with a package name (eg, "nova"), a directory
        suffix (eg, "20160101T120000Z"), a Version object
        (which may be specified as a string on creation),
        a cache filename (sans cache directory),
        and a service name (eg, "nova-api").
    """

    def __init__(self, package=None, service=None,
                 suffix=None, version=None, tarball=None):
        # Only initialise attributes if they're given;
        # we catch missing ones this way.
        if package is not None:
            self.package = package
        if service is not None:
            self.service = service
        if suffix is not None:
            self.suffix = suffix
        if isinstance(version, Version):
            self.version = version
        elif version is VERSION_LATEST:
            self.version = version
        elif version is not None:
            self.version = from_str(version)
        if tarball is not None:
            self.tarball = tarball


def test():
    v1 = Version([[3, 0, 0], ['20160501T120000Z']])
    assert str(v1) == '3.0.0:20160501T120000Z'

    v2 = from_str('3.0.0:20160501T120000Z')
    assert v1 == v2


if __name__ == '__main__':
    test()
