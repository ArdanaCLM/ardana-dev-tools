#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
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
"""
The command-line entry point of the indexer tool.

In order to work with both filesystem and http-based
repositories, a package index is supplied alongside
the relevant binary artifacts.

Multiple versions of the same package can co-exist
in the same index.

The naming scheme is simple and explicit:

package-version.tgz

The package file is a textual index of those packages.

TODO: Add the option to do package signing.
"""

import argparse
import collections
import multiprocessing
import os
import os.path
import yaml

from ardana_packager.config import PACKAGE_FILE, TAR_FORMAT  # noqa
from ardana_packager.error import InstallerError
import ardana_packager.version


def main():
    parser = argparse.ArgumentParser(
        description='Create an ardana_packager index')
    parser.add_argument('--dir', type=str, default='.',
                        help='directory to process')

    args = parser.parse_args()
    create_index(args.dir)


def create_index(dir):
    """Create an index file from the contents of a directory

    Write it out, but also return it, in case it's useful.
    """
    packages = {}

    existing_index_files = []
    try:
        existing_index = load_index(dir)
    except IOError:
        pass
    else:
        packages.update(existing_index["packages"])

        for package in existing_index["packages"].itervalues():
            for package_version in package.itervalues():
                existing_index_files.append(package_version["file"])

    files = os.listdir(dir)
    # Remove from `packages` the venvs for each service that is not
    # there anymore
    files_to_remove = set(existing_index_files) - set(files)
    _packages = collections.defaultdict(dict)
    _packages.update({
        k: { _k: _v for _k, _v in v.iteritems()
             if _v['file'] not in files_to_remove }
        for k, v in packages.iteritems()
    })
    packages = _packages

    # New files that potentially can be new venvs that we need to add
    # to the index file
    files_to_add = set(files) - set(existing_index_files)
    files = [os.path.join(dir, file) for file in files_to_add]

    pool = multiprocessing.Pool(multiprocessing.cpu_count() * 4)
    file_to_version = pool.map(get_version, files)

    for file, version, package, suffix in file_to_version:
        if version is None:
            continue
        packages[package][str(version)] = {
            'file': file,
            'suffix': suffix,
            # Might put more metadata in here later
        }

    index = {
        'index_format': 2,
        'packages': dict(packages)
    }
    write_index(index, dir)
    return index


def get_version(tarfile):
    """Map a tarball filename onto a tuple:

        (filename, version.Version, package 'basename', package suffix)
        If there's a problem, return None.
    """
    if not os.path.isfile(tarfile):
        return None, None, None, None
    match = TAR_FORMAT.match(os.path.basename(tarfile))
    if not match:
        return None, None, None, None
    try:
        return (os.path.basename(tarfile),
                ardana_packager.version.from_tarball(tarfile),
                match.group(1), match.group(2))
    except InstallerError:
        return None, None, None, None


def write_index(index, dir, file=PACKAGE_FILE):
    """Write an index out to a file."""
    target = os.path.join(dir, file)
    with open(target, 'w') as f:
        yaml.dump(index, f)


def load_index(dir, file=PACKAGE_FILE):
    """Load an index from a file

    TODO: This really wants wrapping up in a class,
    but for the moment there are more pressing things to do.
    """
    target = os.path.join(dir, file)
    with open(target) as f:
        return yaml.load(f)


if __name__ == '__main__':
    main()
