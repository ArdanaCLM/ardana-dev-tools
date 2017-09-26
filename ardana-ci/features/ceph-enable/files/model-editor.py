#!/usr/bin/python
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

from __future__ import print_function

import argparse
import copy
import os
import os.path
import yaml


def main():
    parser = argparse.ArgumentParser(
        description='Ceph-enable model editor')

    parser.add_argument('dir', type=str,
                        help='location of cloud config')

    args = parser.parse_args()
    edit(args.dir)


def edit(top):
    for dir, subdirs, files in os.walk(top):
        for file in files:
            try:
                with open(os.path.join(dir, file)) as f:
                    content = yaml.safe_load(f)
                    content_orig = copy.deepcopy(content)
                try:
                    content = massage(content)
                except Exception:
                    content = None
                if content is not None and content != content_orig:
                    print("file **altered**:", file)
                    with open(os.path.join(dir, file), "w") as f:
                        yaml.dump(content, stream=f)
                else:
                    print("file unaltered:", file)
            except IOError:
                pass


def massage(content):
    if content['product']['version'] != 2:
        return None

    for dm in content['disk-models']:
        if 'device-groups' in dm:
            dm['device-groups'] = [dg for dg in dm['device-groups']
                                   if dg.get('name') != 'cinder-volume']

    return content


if __name__ == '__main__':
    main()
