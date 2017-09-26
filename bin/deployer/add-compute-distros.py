#!/usr/bin/env python
#
# (c) Copyright 2017 Hewlett Packard Enterprise Development LP
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
# Runs in the deployer.
#

import argparse
import os

import yaml


class InvalidCloudNameError(StandardError):
    def __init__(self, *args, **kwargs):
        super(InvalidCloudNameError, self).__init__(*args, **kwargs)


class NoCloudNameError(StandardError):
    def __init__(self, *args, **kwargs):
        super(NoCloudNameError, self).__init__(*args, **kwargs)


class InvalidHPCIBasePathError(StandardError):
    def __init__(self, *args, **kwargs):
        super(InvalidHPCIBasePathError, self).__init__(*args, **kwargs)


class InvalidHPCICloudPathError(StandardError):
    def __init__(self, *args, **kwargs):
        super(InvalidHPCICloudPathError, self).__init__(*args, **kwargs)


class InvalidServersPathError(StandardError):
    def __init__(self, *args, **kwargs):
        super(InvalidServersPathError, self).__init__(*args, **kwargs)


class Servers(object):

    _DISTRO_ID_MAP = dict(sles12="sles12sp2-x86_64",
                          rhel7="rhel72-x86_64")

    def __init__(self, cloud=None, hpci_base=None):
        if cloud is None:
            raise NoCloudNameError("No cloud name specified when creating "
                                   "%s object" % (self.__class__.__name__))

        if hpci_base is None:
            hpci_base = os.path.join(os.environ["HOME"], "ardana-ci")

        if not os.path.exists(hpci_base):
            raise InvalidHPCIBasePathError("Invalid ardana-ci directory: '%s'" %
                                           hpci_base)

        cloud_base = os.path.join(hpci_base, cloud)
        if not os.path.exists(cloud_base):
            raise InvalidHPCICloudPathError("Specified ardana-ci cloud directory "
                                            "doesn't exist: '%s'" %
                                            cloud_base)

        servers_file = os.path.join(cloud_base, "data", "servers.yml")
        if not os.path.exists(servers_file):
            raise InvalidHPCICloudPathError("Specified servers file doesn't "
                                            "exist: '%s'" % servers_file)

        self._cloud = cloud
        self._hpci_base = hpci_base
        self._cloud_base = cloud_base
        self._servers_file = servers_file
        self._servers_data = None
        self._dirty = False

    @property
    def cloud(self):
        return self._cloud

    @property
    def hpci_base(self):
        return self._hpci_base

    @property
    def cloud_base(self):
        return self._cloud_base

    @property
    def servers_file(self):
        return self._servers_file

    @property
    def servers_data(self):
        if self._servers_data is None:
            self._load_servers()

        return self._servers_data

    @property
    def dirty(self):
        return self._dirty

    @property
    def servers(self):
        return list(self.servers_data['servers'])

    @property
    def computes(self):
        return [s for s in self.servers if "COMPUTE" in s['role']]

    def _load_servers(self):
        with open(self.servers_file) as fp:
            self._servers_data = yaml.load(fp)

    def _save_servers(self):
        with open(self.servers_file, "w") as fp:
            yaml.dump(self._servers_data, fp)

    def commit(self):
        if self.dirty and self._servers_data:
            self._save_servers()

    def set_compute_distro_id(self, compute, distro="hlinux"):
        distro_id = self._DISTRO_ID_MAP.get(distro, None)

        # if an entry exists in distro ids map
        if distro_id:
            # if existing distro-id is not required value
            if compute.get("distro-id") != distro_id:
                # set/update distro-id value
                compute["distro-id"] = distro_id

                # mark servers object as dirty
                self._dirty = True
        else:
            # no entry in map means use implict distro-id, so remove
            # any existing distro-id entry in compute
            if "distro-id" in compute:
                del compute["distro-id"]

                # mark servers object as dirty
                self._dirty = True


def main():
    parser = argparse.ArgumentParser(description='Configure compute distros')
    parser.add_argument('cloud',
                        help='Name of cloud being deployed')
    parser.add_argument('--no-hlinux', dest='hlinux', action="store_false",
                        help='Skip configuring hlinux computes')
    parser.add_argument('--rhel7', dest='rhel7', action="store_true",
                        help='Configure rhel7 computes')
    parser.add_argument('--sles12', dest='sles12', action="store_true",
                        help='Configure sles12 computes')

    args = parser.parse_args()

    known_distros = ['hlinux', 'sles12', 'rhel7']
    required_distros = [d for d in known_distros if getattr(args, d)]

    servers = Servers(args.cloud)

    num_distros = len(required_distros)
    if num_distros > len(servers.computes):
        parser.error("Specified cloud '%s' only has %d computes but %d "
                     "distros have been specified: %s" %
                     (args.cloud, len(servers.computes), num_distros,
                      required_distros))

    # set distro-id appropriately for last num_distros computes
    for compute, distro in zip(servers.computes[-len(required_distros):],
                               required_distros):
        servers.set_compute_distro_id(compute, distro)

    # write out changes if necessary
    servers.commit()


if __name__ == '__main__':
    main()
