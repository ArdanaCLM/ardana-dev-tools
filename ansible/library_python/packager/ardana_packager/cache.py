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
The cache handler.

This downloads packages.
"""

import os
import os.path
import requests

from ardana_packager.config import PACKAGE_FILE, VERSION_LATEST  # noqa
from ardana_packager.error import InstallerError
from ardana_packager.version import from_str, best_guess  # noqa
import ardana_packager.indexer as indexer


def cache_file(config, spec):
    return os.path.join(config.CACHE_DIR, spec.tarball)


def create_cache(config):
    if not os.path.isdir(config.CACHE_DIR):
        os.mkdir(config.CACHE_DIR, 0o755)


def update(config):
    # Get the new config.
    create_cache(config)

    # Where are we getting the index from?
    url = config.repo_url
    # TODO(jan): configure the proxy
    r = requests.get(url + PACKAGE_FILE)
    assert r.status_code == 200
    after = r.text

    target = os.path.join(config.CACHE_DIR, PACKAGE_FILE)

    changed = False
    before = ""
    try:
        with open(target, 'r') as f:
            before = f.read()
    except IOError:
        changed = True

    if changed or (after != before):
        # Write out the new index
        with open(target, 'w') as f:
            f.write(after)
        return True

    return False


def _download(url, target):
    # TODO(jan): configure the proxy
    r = requests.get(url, stream=True)
    with open(target, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024 * 1024):
            if chunk:
                f.write(chunk)
                f.flush()
    r.close()


def assert_package_present(config, spec):
    index = indexer.load_index(config.CACHE_DIR)

    if 'packages' not in index:
        raise InstallerError(
            "Badly formed index file in {cache_dir}"
            .format(cache_dir=config.CACHE_DIR))
    packages = index['packages']

    if spec.package not in packages:
        raise InstallerError(
            "{package} not listed in index in {cache_dir}"
            .format(package=spec.package, cache_dir=config.CACHE_DIR))
    available = index['packages'][spec.package]

    if spec.version is VERSION_LATEST:
        try:
            v = max(available.keys(), key=from_str)
            spec.version = from_str(best_guess(v))
        except KeyError:
            raise InstallerError(
                "no versions of {package} are not available"
                .format(package=spec.package))

    if str(spec.version) not in available:
        raise InstallerError(
            "{version} of {package} is not available"
            .format(package=spec.package, version=str(spec.version)))

    spec.tarball = available[str(spec.version)]['file']
    spec.suffix = available[str(spec.version)]['suffix']

    source = config.repo_url + spec.tarball
    target = os.path.join(config.CACHE_DIR, spec.tarball)

    if not os.path.isfile(target):
        # If the file's there, assume we've nothing to do
        _download(source, target)

    return spec
