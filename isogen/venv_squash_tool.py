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

from __future__ import print_function

import argparse
import logging
import os
import os.path
import sys
import tarfile
import urllib
import yaml

import venv_diff_report


LOG = logging.getLogger(__name__)


def read_yaml(filename):
    with open(filename, "r") as f:
        return yaml.load(f)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", help="Input file for report",
                        default="report.yml")
    parser.add_argument("--previousurl",
                        help="URL of the previous tarball.")
    parser.add_argument("previous", help="Previous iso mount path or tarball")
    parser.add_argument("scratch", help="Scratch area")
    parser.add_argument("artifacts_list",
                        help="Location of artifacts list file")

    args = parser.parse_args()

    y = read_yaml(args.report)
    print(y['hlinux_venv.tar']['dupes'])

    if not venv_diff_report.check_valid_iso_kit(args.previous):
        print("Invalid previous kit")
        sys.exit(1)

    prev_kit = venv_diff_report.Kit(args.previous)
    ardana_tar_file = prev_kit.get_top_level_kit()
    prefix, version, build = venv_diff_report.get_top_level_kit_parts(
        ardana_tar_file)

    # TODO(kerrin) support more venv tarballs - like RHEL
    venv_tar_name = "hlinux_venv.tar"

    with tarfile.open(name=ardana_tar_file, mode="r") as kittar:
        venv_tar_filename = os.path.join(prefix, venv_tar_name)
        venv_tar = kittar.extractfile(venv_tar_filename)

        with tarfile.open(fileobj=venv_tar, mode="r") as venvstar:
            for package, versions in y[venv_tar_name]['dupes'].items():
                print(
                    "Found duplicate package %s so using older version %s" % (
                        package, versions["previous"]))

                # Write out the old venv package
                old_filename = "./%s-%s.tgz" % (package, versions["previous"])
                outname = os.path.join(args.scratch, old_filename)

                oldvenv = venvstar.extractfile(old_filename)
                with open(outname, "w") as fp:
                    fp.write(oldvenv.read())

                # Download and write out the old manifest file.
                old_manifestname = "%s.manifest-%s" % (
                    package, versions["previous"])
                oldmanifesturl = os.path.join(
                    args.previousurl,
                    "manifests",
                    old_manifestname)
                oldmanifest = urllib.urlopen(oldmanifesturl).read()
                oldmanifestfile = os.path.join(args.scratch, old_manifestname)
                with open(oldmanifestfile, 'w') as fp:
                    fp.write(oldmanifest)

                # Remove the 'newer' venv & manifest file
                os.remove(os.path.join(
                    args.scratch, "%s-%s.tgz" % (package, versions["new"])))
                new_manifestname = "%s.manifest-%s" % (
                    package, versions["new"])
                os.remove(os.path.join(args.scratch, new_manifestname))

                # Update the artifacts file
                artifacts = []
                with open(args.artifacts_list, "r") as fp:
                    for line in fp:
                        data = line.split()
                        if data[0] == package:
                            if data[3].endswith(new_manifestname):
                                # lines has \n at the end so make
                                # this compatable
                                artifacts.append(
                                    "%s %s %s %s\n" % (
                                        data[0],
                                        data[1],
                                        versions["previous"],
                                        os.path.abspath(
                                            oldmanifestfile)
                                    )
                                )
                            else:
                                artifacts.append(
                                    "%s %s %s %s\n" % (
                                        data[0],
                                        data[1],
                                        versions["previous"],
                                        os.path.abspath(outname)
                                    )
                                )
                        else:
                            artifacts.append(line)

                with open(args.artifacts_list, "w") as fp:
                    fp.write("".join(artifacts))


if __name__ == "__main__":
    main()
