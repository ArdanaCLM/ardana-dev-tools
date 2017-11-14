#!/usr/bin/env python
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
Script to manage squashing kits so we only include newer versions of packages
when they change
"""

from __future__ import print_function

import argparse
import glob
import os
import re
import shutil
import sys
import tarfile
import tempfile
import yaml


VENV_FILENAME_PATTERN = \
    re.compile("(.*)-([0-9]{8}T[0-9]{6}Z|\d+\.\d+\.\d+)(\.h\w{3,})?(\.tgz)")


def read_yaml(filename):
    with open(filename, "r") as f:
        return yaml.load(f)


def get_top_level_kit(path):
    """Turn an iso mount path into a ardana-N.X.X.X-XXXXXXXXXXXXX.tar filename"""
    ardana_path = os.path.join(path, "ardana")
    if not os.path.isdir(ardana_path):
        raise(KeyError("path does not contain a ardana directory: %s" % path))

    globs = glob.glob(os.path.join(ardana_path, "ardana-*Z.tar"))
    if len(globs) == 0:
        raise(KeyError("path does not contain a ardana kit: %s" % path))
    if len(globs) > 1:
        raise(KeyError("path does not contain expected file structure: %s" %
                       path))

    return globs[0]


def process_venv_file(newtar, entry, filename, dupes):
    temp_tar = None
    temp = None
    try:
        temp = tempfile.NamedTemporaryFile()
        print("Using tempfile: %s" % temp.name)
        temp_tar = tarfile.open(name=temp.name, mode="w")
        with tarfile.open(fileobj=entry, mode="r") as venvs:
            for f in venvs:
                if f.isreg():
                    data = VENV_FILENAME_PATTERN.match(
                        os.path.basename(f.name))
                    if data:
                        package = data.group(1)
                        if package in dupes:
                            print("Skipping the copying of %s" % package)
                        else:
                            print("Copying venv %s" % package)
                            fileobj = venvs.extractfile(f)
                            temp_tar.addfile(f, fileobj=fileobj)
                    else:
                        print("Copying non-venv %s" % f.name)
                        fileobj = venvs.extractfile(f)
                        temp_tar.addfile(f, fileobj=fileobj)
                else:
                    print("Copying non-regular file %s" % f.name)
                    fileobj = venvs.extractfile(f)
                    temp_tar.addfile(f, fileobj=fileobj)
        temp_tar.close()
        newtar.add(temp.name, arcname=entry.name)
    finally:
        if temp_tar:
            temp_tar.close()
        if temp:
            temp.flush()
            temp.close()


def make_iso_kit(src, outputdir, dupes_map):
    tars = [k for k in dupes_map.keys() if k.endswith(".tar")]
    print("Looking for tar files: %s" % tars)

    print("Copying kit to %s" % outputdir)
    shutil.copytree(src, outputdir, symlinks=True)

    new_ardana_tar_filename = get_top_level_kit(outputdir)
    old_ardana_tar_filename = get_top_level_kit(src)
    print("Removing incorrect ardana.XXX.tar: %s" % new_ardana_tar_filename)
    os.remove(new_ardana_tar_filename)

    with tarfile.open(old_ardana_tar_filename, "r") as old_ardana:
        with tarfile.open(new_ardana_tar_filename, "w") as new_ardana:
            for f in old_ardana:
                base = os.path.basename(f.name)
                if base in dupes_map:
                    print("Processing venv set %s" % f.name)
                    dupes = dupes_map[base]["dupes"]
                    print("Dupes are: %s" % dupes)
                    entry = old_ardana.extractfile(f)
                    process_venv_file(new_ardana, entry, f.name, dupes)
                else:
                    print("Copying file %s" % f.name)
                    fileobj = old_ardana.extractfile(f)
                    new_ardana.addfile(f, fileobj=fileobj)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("iso", help="iso mount path")
    parser.add_argument("--report", help="Input file for report",
                        default="report.yml")
    parser.add_argument("--outputdir", help="path to write squashed kit to",
                        default=None)
    args = parser.parse_args()

    if not args.outputdir:
        print("--outputdir required")
        sys.exit(1)

    if os.path.exists(args.outputdir):
        print("Output directory already exists: %s" % args.outputdir)
        sys.exit(1)

    y = read_yaml(args.report)
    make_iso_kit(args.iso, args.outputdir, y)


if __name__ == "__main__":
    main()
