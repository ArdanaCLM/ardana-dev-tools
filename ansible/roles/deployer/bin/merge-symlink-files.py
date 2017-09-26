#!/usr/bin/env python
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

import argparse
import glob
import os.path
import yaml


def main():
    parser = argparse.ArgumentParser(
        description='Merge symlink yaml files')
    parser.add_argument('in_files', type=str,
                        help='Location (glob) of input yaml files')
    parser.add_argument('--key', type=str, action='append',
                        help='Name of yaml key to merge on',
                        default=[])
    parser.add_argument('--config-path', type=str, action='store',
                        help='Location of the config directory.')
    parser.add_argument('--target-path', type=str, action='store',
                        help='Location of the target directory.')
    parser.add_argument('--source-path', type=str, action='store',
                        help='Location of the source directory.')

    args = parser.parse_args()
    if len(args.key) == 0:
        args.key = ['symlinks']

    config_dir = args.config_path
    target_dir = args.target_path
    source_dir = args.source_path

    for fn in glob.glob(args.in_files):
        with open(fn) as f:
            temp = yaml.safe_load(f)
        for key in args.key:
            for src, dest in temp.get(key, {}).items():
                d = os.path.join(config_dir, src)
                p_d = os.path.dirname(d)

                # The logic here to reproduce the j2 declaration
                # "{{ deployer_symlink_target_path |
                #     joinpath(item.value) |
                #     relpath(deployer_symlink_sourcee_path |
                #             joinpath(item.key) |
                #             dirname)
                #  }}"
                # in python.
                s_1 = os.path.join(target_dir, dest)
                s = os.path.dirname(os.path.join(source_dir, src))

                if not os.path.exists(p_d):
                    os.makedirs(p_d)
                os.symlink(os.path.relpath(s_1, s), d)


if __name__ == '__main__':
    main()
