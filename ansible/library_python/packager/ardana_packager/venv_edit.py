#!/usr/bin/python -tt
# -*- coding: utf-8 -*-

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

"""venv_edit ansible module."""

import os
import re
import shutil
import tarfile
from time import strftime

import yaml

DOCUMENTATION = '''
---
module: venv_edit
short_description: Module for updating existing venv with new content.
description:
    - Ansible module for installing additional wheels and python sources
    - into existing venvs, or creating new venvs from scratch.
author: "Seamus Delaney"
requirements:
    - yaml
    - virtualenv
    - pip
options:
    name:
        description:
            - The name the produced venv should have.
              If name is not defined, the src venv's name is used.
        required: false
        default: null
    src:
        description:
            - The venv that we want to update with new content.
        required: false
        default: null
    dest:
        description:
            - The directory for the produced venv.
              If dest is not specified, the src directory is used.
        required: false
        default: null
    wheelhouse:
        description:
            - Directory containing dependencies for wheels.
        required: true
    wheels:
        description:
            - The content you want to update the venv with.
        required: true
    version:
        description:
            - The version of the venv to be created.
        required: true
    patch:
        description:
            - Patch number for the updated venv.
              If this is not defined, the current patch number is incremented.
        required: false
        default: null
'''

EXAMPLES = '''
- venv_edit:
    src: /home/wheelman/source_venv.tgz
    wheelhouse: /home/wheelman/my_wheelhouse
    wheels: /home/wheelman/my_wheel.whl
    version: 4.0.0

- venv_edit:
    src: /home/wheelman/source_venv.tgz
    dest: /home/wheelman/
    wheelhouse: /home/wheelman/my_wheelhouse
    wheels: /home/wheelman/my_wheel.whl
    version: 4.0.0
    patch: 27

- venv_edit:
    name: my_venv
    dest: /home/wheelman/
    wheelhouse: /home/wheelman/my_wheelhouse
    wheels: /home/wheelman/my_wheel.whl
    version: 4.0.1
    patch: 27
'''


def create_venv(module, dest):
    """Create a virtualenv at the specified location."""
    virtualenv_bin = module.get_bin_path('virtualenv')
    virtual_env_cmd = [virtualenv_bin, dest]
    return module.run_command(virtual_env_cmd)


def unpack_venv(tarball_path, target_dir):
    """Explode tarball at target_dir."""
    with tarfile.open(tarball_path) as tarball:
        tarball.extractall(path=target_dir)


def relocate_venv(target_dir):
    """Relocate target venv shebang lines and fix up activate script."""
    venv_bin = os.path.join(target_dir, "bin")
    for filename in os.listdir(venv_bin):
        file_path = os.path.join(venv_bin, filename)
        with open(file_path, 'r') as f:
            file_contents = f.read()
        with open(file_path, 'w') as f:
            new_shebang = re.sub(r'^#!.*',
                                 r'#!{0}/bin/python'.format(target_dir),
                                 file_contents)
            f.write(new_shebang)

    # Fix up activate script
    activate_file_loc = os.path.join(target_dir, "bin/activate")
    with open(activate_file_loc, 'r') as f:
        activate_file = f.read()
    with open(activate_file_loc, 'w') as f:
        new_line = re.sub(r'^VIRTUAL_ENV=".*?"',
                          r'VIRTUAL_ENV="{0}"'.format(target_dir),
                          activate_file,
                          1,
                          re.MULTILINE)
        f.seek(0)
        f.write(new_line)


def add_to_venv(module, target_dir, wheels, wheelhouse):
    """Install wheels into target_dir."""
    activate_file_loc = os.path.join(target_dir, "bin/activate")
    if(not os.path.exists(activate_file_loc)):
        # Create virtualenv at target
        virtualenv_bin = module.get_bin_path('virtualenv')
        venv_command = [virtualenv_bin, target_dir]
        rc, out_venv, err_venv = module.run_command(venv_command)

        if(rc != 0):
            module.fail_json(msg=out_venv,
                             changed=False,
                             results="",
                             errors=err_venv)

    pip_bin = os.path.join(target_dir, "bin/pip")
    pip_command = ("{pip} install {wheels} --no-index "
                   "--find-links {wh}"
                   .format(pip=pip_bin, wheels=wheels, wh=wheelhouse))
    rc, out_pip, err_pip = module.run_command(pip_command)
    if (rc != 0):
        module.fail_json(msg=out_pip,
                         changed=False,
                         results="",
                         errors=err_pip)


def create_metadata(module, target_dir, timestamp, version, patch):
    """Create new metadata files."""
    # Create metadata directory
    metadata_dir = os.path.join(target_dir, "META-INF")
    os.mkdir(metadata_dir)

    # Create version
    version_file = os.path.join(metadata_dir, "version.yml")
    version_yaml = yaml.load("""
        file_format: 1
        version: %s
        timestamp: %s """ % (version, timestamp))

    if patch is not None:
        version_yaml['patch'] = patch

    with open(version_file, 'w') as f:
        yaml.dump(version_yaml, stream=f)

    # Create manifest
    lsb_release_bin = module.get_bin_path('lsb_release')
    lsb_release_cmd = [lsb_release_bin, '-idrc']
    rc, lsb_out, err = module.run_command(lsb_release_cmd)
    lsb_out = lsb_out.lower()
    lsb_out = lsb_out.replace("\t", " ")
    lsb_out = lsb_out.replace("distributor id", "distributor_id")
    manifest_file = os.path.join(metadata_dir, "manifest.yml")
    lsb_yaml = yaml.load(lsb_out)
    manifest_yaml = yaml.load("environment: %s" % yaml.dump(lsb_yaml))

    with open(manifest_file, 'w') as f:
        yaml.dump(manifest_yaml, stream=f)


def update_version(target_dir, patch, derived=False):
    """Update venv patch number."""
    version_file = os.path.join(target_dir, "META-INF", "version.yml")

    with open(version_file) as f:
        version = yaml.safe_load(f)

    if derived and 'patch' in version:
        del version['patch']
    elif not derived:
        with open(version_file) as f:
            version = yaml.safe_load(f)

        try:
            old_patch = int(version['patch'])
        except KeyError:
            old_patch = 0
        except ValueError:
            old_patch = 0

        if patch is None:
            patch = old_patch + 1

        version['patch'] = patch

    with open(version_file, 'w') as f:
        yaml.dump(version, stream=f)


def repackage_venv(new_tarball, target_dir):
    """Repackage venv as a new tarball."""
    with tarfile.open(new_tarball, "w:gz") as tarball:
        tarball.add(target_dir, ".")


def cleanup(target_dir):
    """Remove scratch directories."""
    if(os.path.isdir(target_dir)):
        shutil.rmtree(target_dir)


def main():
    """Module entry point."""
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(default=None),
            src=dict(default=None),
            dest=dict(default=None),
            wheelhouse=dict(required=True),
            wheels=dict(required=True),
            version=dict(required=True),
            patch=dict(default=None)
        ),
        required_one_of=[['src', 'dest']]
    )

    params = module.params
    name = params['name']
    src = params['src']
    dest = params['dest']
    wheelhouse = params['wheelhouse']
    wheels = params['wheels']
    version = params['version']
    patch = params['patch']

    derived = False
    if name is not None and src is not None:
        derived = ("-".join(os.path.basename(src).split('-')[:-1]) != name)

    if name is None:
        if src is None:
            module.fail_json(msg="'src' required if no name specified.")
        else:
            name = "-".join(os.path.basename(src).split('-')[:-1])
    suffix = strftime('%Y%m%dT%H%M%SZ')
    venv_name = name + "-" + suffix
    install_dir = "/opt/stack/venv"
    target_dir = os.path.join(install_dir, venv_name)
    if dest is None:
        dest = os.path.dirname(src)
    dest_full = os.path.join(dest, venv_name + ".tgz")

    try:
        if src is None:  # Creating a venv from scratch
            create_venv(module, target_dir)
            add_to_venv(module, target_dir, wheels, wheelhouse)
            create_metadata(module, target_dir, suffix, version, patch)
        else:  # Using an existing venv as a base
            unpack_venv(src, target_dir)
            relocate_venv(target_dir)
            add_to_venv(module, target_dir, wheels, wheelhouse)
            update_version(target_dir, patch, derived and not patch)

        repackage_venv(dest_full, target_dir)

    finally:
        cleanup(target_dir)

    module.exit_json(changed=True, rc=0)

# import module snippets
from ardana_packager.ansible import *  # noqa
if __name__ == '__main__':
    main()
