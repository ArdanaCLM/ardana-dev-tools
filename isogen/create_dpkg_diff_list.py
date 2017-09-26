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
import fnmatch
import logging
import os
import shutil
import sys


LOG = logging.getLogger(__name__)


def check_valid_kit(path):
    """Sanity check kit at path looks valid"""
    LOG.debug("Sanity checking kit at %s" % path)
    if not os.path.isdir(path):
        print("Path kit does not exist or is not a directory %s" % path)
        return False

    pool_path = os.path.join(path, "pool")
    if not os.path.isdir(pool_path):
        print("No pool dir found inside %s" % path)
        return False

    return True


def filename_matches_pattern_list(filename, patterns):
    """Check if a filename matches a glob style pattern list"""
    for pattern in patterns:
        if fnmatch.fnmatch(filename, pattern):
            return True
    return False


def get_package_list_from_kit(path):
    PACKAGE_PATTERNS = ["*.deb", "*.udeb"]
    packages = []

    for _, _, files in os.walk(path):
        for f in files:
            if filename_matches_pattern_list(f, PACKAGE_PATTERNS):
                packages.append(f)
            else:
                LOG.debug("Unexpected file %s" % f)

    LOG.debug("Found %d packages in %s" % (len(packages), path))

    return packages


def diff_package_list(old_list, new_list):
    new = []
    dupes = []
    removed = []

    new = new_list[:]
    for entry in old_list:
        if entry in new_list:
            new.remove(entry)
            dupes.append(entry)
        else:
            removed.append(entry)

    return new, dupes, removed


def write_output_file(new, dupes, removed, filename):
    """Write the three lists to a yaml file"""
    with open(filename, "w") as f:
        f.write("new:\n")
        for entry in new:
            f.write("  %s\n" % entry)
        f.write("duplicated:\n")
        for entry in dupes:
            f.write("  %s\n" % entry)
        f.write("removed:\n")
        for entry in removed:
            f.write("  %s\n" % entry)


def ignorefn(dupes, rep):
    def _ignore(path, names):
        ignored_names = []
        for f in names:
            if f in dupes and "/pool/" in path:
                ignored_names.append(f)
                rep.append(os.path.join(path, f))
        return set(ignored_names)
    return _ignore


def squash_dpkg_files(newkit, outpath, dupes):
    if os.path.exists(outpath):
        print("Error: Output path %s already exists" % outpath)
        print("Left over from a previous run? Please clean up")
        sys.exit(1)

    rep = []

    # Recursively copy newkit to oldpath, skipping files as necessary
    shutil.copytree(newkit, outpath, symlinks=True,
                    ignore=ignorefn(dupes, rep))

    # rep now contains a list of all the files we need to put back during
    # upgrade, however all entries have 'newkit' as a prefix
    newrep = []
    for entry in rep:
        if entry.startswith(newkit):
            entry = entry[len(newkit):]
        if entry.startswith('/'):
            entry = entry[1:]
        newrep.append(entry)
    rep = newrep

    # Now write out the list of files that need to be stashed during the
    # upgrade so that they can be put back into the pool

    with open(os.path.join(outpath, "pool_duplicate_files.list"), "w") as f:
        for entry in rep:
            f.write(entry)
            f.write("\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("previous", help="Previous kit iso mount path")
    parser.add_argument("new", help="New kit iso mount path")
    parser.add_argument("verbose", help="Verbose output", action="store_true")
    parser.add_argument("--report", help="Output file for report",
                        default=None)
    parser.add_argument("--action", help="[report | squash]", default="report")
    parser.add_argument("--outputdir", help="path to write squashed kit to",
                        default=None)
    args = parser.parse_args()

    if not check_valid_kit(args.previous):
        print("Invalid previous kit")
        sys.exit(1)
    if not check_valid_kit(args.new):
        print("invalid new kit")
        sys.exit(1)

    print("Collecting previous package list")
    prev_list = get_package_list_from_kit(args.previous)
    print("Found %d items" % (len(prev_list)))

    print("Collecting new package list")
    new_list = get_package_list_from_kit(args.new)
    print("Found %d items" % (len(new_list)))

    new, dupes, removed = diff_package_list(prev_list, new_list)

    print("%d new %d duplicated %d removed packages" % (len(new), len(dupes),
                                                        len(removed)))

    if args.report:
        write_output_file(new, dupes, removed, args.report)

    if args.action == "squash":
        if args.outputdir is None:
            raise KeyError("Must specify --outputdir for squashed kit")
        squash_dpkg_files(args.new, args.outputdir, dupes)


if __name__ == "__main__":
    main()
