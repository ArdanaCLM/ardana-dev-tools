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

import glob
from ardana_packager.ansible import AnsibleModule
import os
import os.path
import yaml


def main():
    module = AnsibleModule(
        argument_spec=dict(
            in_files=dict(required=True),
            key=dict(default="symlinks"),
            config_path=dict(required=True),
            target_path=dict(required=True),
            source_path=dict(required=True),
        ),
        supports_check_mode=False
    )

    params = module.params
    in_files = params['in_files']
    if ',' in params['key']:
        keys = [k.strip() for k in params['key'].split(',')]
    else:
        keys = [params['key']]
    config_dir = params['config_path']
    target_dir = params['target_path']
    source_dir = params['source_path']

    changed = False

    for fn in glob.glob(in_files):
        with open(fn) as f:
            temp = yaml.safe_load(f)
        for key in keys:
            for src, dest in temp.get(key, {}).items():
                d = os.path.join(config_dir, src)
                p_d = os.path.dirname(d)

                # The logic here to reproduce the j2 declaration
                # "{{ deployer_symlink_target_path |
                #     joinpath(item.value) |
                #     relpath(deployer_symlink_source_path |
                #             joinpath(item.key) |
                #             dirname)
                #  }}"
                # in python.
                s_1 = os.path.join(target_dir, dest)
                s = os.path.dirname(os.path.join(source_dir, src))

                if not os.path.exists(p_d):
                    os.makedirs(p_d)
                if not os.path.islink(d):
                    os.symlink(os.path.relpath(s_1, s), d)
                    changed = True

    module.exit_json(in_files=in_files,
                     key=','.join(keys),
                     config_path=config_dir,
                     target_path=target_dir,
                     source_path=source_dir,
                     changed=changed)


if __name__ == '__main__':
    main()
