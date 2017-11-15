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
import logging
import os
import yaml

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


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

    _DISTRO_ID_MAP = dict(sles12="sles12sp3-x86_64",
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

    def _load_servers(self):
        with open(self.servers_file) as fp:
            self._servers_data = yaml.load(fp)

    def _save_servers(self):
        with open(self.servers_file, "w") as fp:
            yaml.dump(self._servers_data, fp, default_flow_style=False,
                      indent=4)

    def commit(self):
        if self.dirty and self._servers_data:
            logger.info('Server state changed, saving')
            self._save_servers()
        else:
            logger.info('Server state did not change, not saving')

    def set_distro_id(self, server, distro="hlinux"):
        distro_id = self._DISTRO_ID_MAP.get(distro, None)

        # if an entry exists in distro ids map
        if distro_id:
            # if existing distro-id is not required value
            if server.get("distro-id") != distro_id:
                logger.info('Distro id %s for server %s does not match %s, '
                            'updating' % (distro_id, server['id'],
                                          server.get("distro-id", 'default')))
                # set/update distro-id value
                server["distro-id"] = distro_id

                # mark servers object as dirty
                self._dirty = True
            else:
                logger.info('Distro id %s for server %s unchanged' %
                            (distro_id, server['id']))
        else:
            # no entry in map means use implict distro-id, so remove
            # any existing distro-id entry in server
            if "distro-id" in server:
                logger.info('Distro id %s for server %s is not default, '
                            ' removing' % (server["distro-id"], server['id']))
                del server["distro-id"]

                # mark servers object as dirty
                self._dirty = True
            else:
                logger.info('Default distro id for server %s unchanged' %
                            (server['id']))


def main():

    def str2bool(arg):
        return arg.lower() in ("yes", "true", "1")

    parser = argparse.ArgumentParser(description='Configure compute distros')
    parser.add_argument('cloud',
                        help='Name of cloud being deployed')
    parser.add_argument('--sles-deployer', dest='sles_deployer',
                        help='Configure deployer to run on SLES')
    parser.add_argument('--sles-compute', dest='sles_compute',
                        help='Configure all compute nodes to run on SLES')
    parser.add_argument('--sles-compute-nodes', dest='sles_compute_nodes',
                        help='Configure selected compute nodes to run on SLES'
                        '(colon-separated list)')
    parser.add_argument('--sles-control', dest='sles_control',
                        help='Configure all control nodes to run on SLES')
    parser.add_argument('--sles-control-nodes', dest='sles_control_nodes',
                        help='Configure selected control nodes to run on SLES'
                        '(colon-separated list)')
    parser.add_argument('--rhel-compute', dest='rhel_compute',
                        help='Configure all compute nodes to run on RHEL')
    parser.add_argument('--rhel-compute-nodes', dest='rhel_compute_nodes',
                        help='Configure selected compute nodes to run on RHEL'
                        '(colon-separated list)')

    args = parser.parse_args()
    servers = Servers(args.cloud)

    sles_compute_node_ids = args.sles_compute_nodes.split(':')
    sles_control_node_ids = args.sles_control_nodes.split(':')
    rhel_compute_node_ids = args.rhel_compute_nodes.split(':')

    for i, server in enumerate(servers.servers):
        if "COMPUTE" in server['role']:
            if str2bool(args.sles_compute) or \
                    server['id'] in sles_compute_node_ids:
                servers.set_distro_id(server, 'sles12')
            elif str2bool(args.rhel_compute) or \
                    server['id'] in rhel_compute_node_ids:
                servers.set_distro_id(server, 'rhel7')
            else:
                servers.set_distro_id(server, 'hlinux')
        elif "CONTROL" in server['role']:
            if str2bool(args.sles_control) or \
                    server['id'] in sles_control_node_ids:
                servers.set_distro_id(server, 'sles12')
            else:
                servers.set_distro_id(server, 'hlinux')
        # Treat 1st server in the list as deployer
        elif i == 0 and "CONTROL" not in server['role']:
            if str2bool(args.sles_deployer):
                servers.set_distro_id(server, 'sles12')
            else:
                servers.set_distro_id(server, 'hlinux')
        else:
            logger.info('Unrecognized node type %s, not changing distro' %
                        server['role'])

    # write out changes if necessary
    servers.commit()


if __name__ == '__main__':
    main()
