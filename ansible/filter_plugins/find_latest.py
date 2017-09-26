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
import os
import os.path
import pkg_resources
import re


# Take a directory and return a dictionary of
# { name: (version, package name and package manifest) }
# of all valid packages found there.
def find_latest_packages(directory, deployer_version):
    # If we are skipping a task, but we execute this filter without
    # the directory, then we ansible tries to iterate over an exception
    if not os.path.exists(directory):
        return {}

    package_re = re.compile(
        "(\w+-*\w*)-([0-9]{8}T[0-9]{6}Z|%s).tgz$" % deployer_version)
    packages = {}
    for item in os.listdir(directory):
        item_p = package_re.match(item)
        if not item_p:
            continue
        (name, version) = item_p.groups()
        if name in packages:
            parsed_version = pkg_resources.parse_version(version)
            latest_so_far = pkg_resources.parse_version(packages[name][0])
            if parsed_version <= latest_so_far:
                continue
        manifest = "%s.manifest-%s" % (name, version)
        packages[name] = (version, item, manifest)

    return packages


class FilterModule(object):
    def filters(self):
        return {'find_latest_packages': find_latest_packages}
