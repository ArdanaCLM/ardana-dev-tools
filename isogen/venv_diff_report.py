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
# Script to manage squashing kits so we only include newer versions of packages
# when they change
#


from __future__ import print_function

import argparse
import collections
import fnmatch
import glob
import hashlib
import logging
import os
import re
import sys
import tarfile
import yaml


LOG = logging.getLogger(__name__)
VERBOSE = False


# TODO(kerrin) figure out how to generalize this
VENV_FILENAME_PATTERN = \
    re.compile("(.*)-([0-9]{8}T[0-9]{6}Z|\d\.\d\.\d)(\.h\w{3,})?(\.tgz)")
# Some packages we know won't ever cause changes to binaries in venvs
# - This list is non-exhausive, but for safety should probably only be added
#   to when a package is found to be unexpectedly triggering the non-removal
#   of venvs ina hotfix kit, rather than speculatively
SAFE_PACKAGES = ["sed", "tar", "eject", "grep", "screen"]

VENV_TARS = ["hlinux_venv.tar", "venv.tar", "rhel7-venv.tar"]

SCRATCH_DIRS = ["."]  # , "redhat"]

# Using a global for this is not very clean, but neither is passing the value
# into constructors repeatedly
BINARY_BUILD_ENVIRONMENT_MATCHES = True


def check_valid_iso_kit(path):
    """Sanity check iso kit at path looks valid"""
    LOG.debug("Sanity checking iso kit at %s" % path)
    if not os.path.isdir(path):
        LOG.debug("check_valid_iso_kit: Path kit does not exist or is not"
                  "a directory %s" % path)
        return False

    pool_path = os.path.join(path, "pool")
    if not os.path.isdir(pool_path):
        LOG.debug("check_valid_iso_kit: No pool dir found inside %s" % path)
        return False

    ardana_path = os.path.join(path, "ardana")
    if not os.path.isdir(ardana_path):
        LOG.debug("check_valid_iso_kit: No ardana dir found inside %s" % path)
        return False

    return True


def check_valid_deployer_tar(path):
    """Sanity check deployer tar at path looks valid"""
    LOG.debug("Sanity checking deployer tarball at %s" % path)
    if not os.path.isfile(path):
        LOG.debug("check_valid_deployer_tar: Path is not a regular file: %s"
                  % path)
        return False

    try:
        with tarfile.open(name=path, mode="r") as tar:
            files = []
            for f in tar:
                files.append(f.name)
#            if not foo in files:
#               complain loudly
    except Exception as e:
        LOG.debug("Exception examining tar file %s: %s" % (path, e))
        print("check_valid_deployer_tar: exception %s" % e)
        return False

    return True


def get_top_level_kit_parts(kit):
    """Extract details from kit filename

    Return the kit name (e.g. ardana-0.9.0) and build version from a kit
    filename
    """
    filename = os.path.basename(kit)
    # FIXME(DuncanT): Needs to be generalised
    ARDANA_KIT_PATTERN = \
        re.compile("(ardana-([0-9].[0-9]+.[0-9]+))-([0-9]{8}T[0-9]{6}Z)")
    match = ARDANA_KIT_PATTERN.match(filename)

    if match is None:
        raise Exception("Invalid kit format")

    name = match.group(1)
    version = match.group(2)
    build = match.group(3)

    return (name, version, build)


class VenvFolderEntry(object):
    def __init__(self, name, mode, uid, gid):
        self.name = name
        self.mode = mode
        self.uid = uid
        self.gid = gid


class VenvEntry(object):
    def __init__(self, name, size, mode, uid, gid, fileobj):
        self.filetype = "file"
        self.name = name
        self.size = size
        self.mode = mode
        self.uid = uid
        self.gid = gid
        self.special_files_init(name, fileobj)

    def special_files_init(self, name, fileobj):
        # Note that these patterns are called with 'match' so much
        # match the entire of the filename
        RECORD_FILES_PATTERN = \
            re.compile("^./lib/python[0-9\.]+/.*dist-info/RECORD$")
        PYTHON_FILES_PATTERN = re.compile(".*\.py$")
        SO_FILES_PATTERN = re.compile(".*\.so$")
        PYO_FILES_PATTERN = re.compile(".*\.pyo$")
        BIN_FILES_PATTERN = re.compile("^./bin/.*$")
        SELF_CHECK_JSON_PATTERN = re.compile("^./pip-selfcheck.json$")
        PIP_LOG_PATTERN = re.compile("^./bin/pip.log$")

        if RECORD_FILES_PATTERN.match(name):
            self.filetype = "record"
            self.sha1 = self._get_RECORD_sha1(fileobj)
        elif PYTHON_FILES_PATTERN.match(name):
            self.filetype = "python"
            self.sha1 = self._get_python_sha1(fileobj)
        elif SO_FILES_PATTERN.match(name):
            self.filetype = "so"
            self.sha1 = self._get_so_sha1(fileobj)
        elif PYO_FILES_PATTERN.match(name):
            self.filetype = "pyo"
            self.sha1 = self._get_sha1(fileobj)
        elif PIP_LOG_PATTERN.match(name):
            self.filetype = "pip.log"
            self.sha1 = self._get_pip_log_sha1(fileobj)
        elif BIN_FILES_PATTERN.match(name):
            self.filetype = "bin"
            self.sha1 = self._get_bin_sha1(name, fileobj)
        elif SELF_CHECK_JSON_PATTERN.match(name):
            self.filetype = "pip-selfcheck.json"
            self.sha1 = self._get_pip_selfcheck_json(fileobj)
        else:
            self.filetype = "generic"
            self.sha1 = self._get_sha1(fileobj)

    def _get_python_sha1(self, fileobj):
        sha1 = hashlib.sha1()
        fileobj.seek(0)
        buf = fileobj.read()
        lines = buf.split("\n")
        if lines[0].startswith("#!/"):
            buf = buf[len(lines[0]):]
        sha1.update(buf)
        return sha1.hexdigest()

    def _get_pip_selfcheck_json(self, fileobj):
        """Handle pip-selfcheck.json files

        Since these change entirely between even identical builds and do not
        contain anything pertinent to our purposes, just fake out the SHA1
        """
        return "NO SHA POSSIBLE"

    def _get_so_sha1(self, fileobj):
        global BINARY_BUILD_ENVIRONMENT_MATCHES

        if BINARY_BUILD_ENVIRONMENT_MATCHES:
            return "NO SHA POSSIBLE"
        else:
            return self._get_sha1(fileobj)

    def _get_bin_sha1(self, filename, fileobj):
        """/bin/* sha1

        We treat python scripts and '/bin/activate*' specially. More special
        cases may be found in future
        """
        sha1 = hashlib.sha1()
        fileobj.seek(0)
        buf = fileobj.read()
        lines = buf.split("\n")
        linesout = lines[:]
        if lines[0].startswith("#!/") and "python" in lines[0]:
            linesout.remove(lines[0])
        for line in lines:
            if filename == "./bin/activate":
                if line.startswith("VIRTUAL_ENV=\"/opt/stack/venv/"):
                    linesout.remove(line)
            if filename == "./bin/activate.csh":
                if line.startswith("setenv VIRTUAL_ENV \"/opt/stack/venv/"):
                    linesout.remove(line)
            if filename == "./bin/activate.fish":
                if line.startswith("set -gx VIRTUAL_ENV \"/opt/stack/venv/"):
                    linesout.remove(line)
        buf = "\n".join(linesout)
        sha1.update(buf)
        return sha1.hexdigest()

    def _get_pip_log_sha1(self, fileobj):
        """/bin/pip.log handling"""
        sha1 = hashlib.sha1()
        fileobj.seek(0)
        buf = fileobj.read()
        lines = buf.split("\n")
        linesout = lines[:]
        for line in lines:
            if line.startswith("Location: "):
                linesout.remove(line)
        buf = "\n".join(linesout)
        sha1.update(buf)
        return sha1.hexdigest()

    def _get_RECORD_sha1(self, fileobj):
        """Python package RECORD file handling

        RECORD files contain sha256 checksums of bits of the contents of the
        package. Since some of these will be binary files that have #! lines
        that have the venv build id in them, we remove those lines from the
        RECORD file before we generate our checksum
        """
        SKIP_PATTERNS = [re.compile("^../../../bin/.*"),
                         re.compile("^/opt/stack/venv/.*/bin/.*")]
        sha1 = hashlib.sha1()
        fileobj.seek(0)
        buf = fileobj.read()
        lines = buf.split("\n")
        linesout = lines[:]
        for line in lines:
            try:
                filename = line.split(",")[0]
                for pattern in SKIP_PATTERNS:
                    if pattern.match(filename):
                        linesout.remove(line)
            except IndexError:
                pass
        buf = "\n".join(linesout)
        sha1.update(buf)
        return sha1.hexdigest()

    def _get_sha1(self, fileobj):
        sha1 = hashlib.sha1()
        fileobj.seek(0)
        for buf in fileobj.read(4096):
            sha1.update(buf)
        return sha1.hexdigest()

    def __str__(self):
        return self.__repr__()

    def __repr__(self):
        return "%s %d" % (self.name, self.size)

    def __eq__(self, other):
        if other is None:
            return False

        if type(other) is not type(self):
            raise TypeError("%s is not %s for comparison" %
                            (type(other), type(self)))

        if self.name != other.name:
            print("Name mismatch for %s (%s)" % (self.name, other.name))
            return False

        if self.size != other.size \
           or self.mode != other.mode \
           or self.uid != other.uid \
           or self.gid != other.gid:
            print("Attribute mismatch for %s" % self.name)
            return False

        if self.sha1 != other.sha1:
            print("SHA1 mismatch for %s (%s)" % (self.name, self.filetype))
            global BINARY_BUILD_ENVIRONMENT_MATCHES
            if (((self.filetype in ["so", "pyo"]) and
                 (BINARY_BUILD_ENVIRONMENT_MATCHES))):
                print(" - Ignoring it since it is a recognised binary")
                return True
            else:
                return False

        return True


class Venv(object):
    IGNORED_PATTERNS = ["./META-INF/*"]

    def __init__(self, name, fileobj):
        self.name = name
        self.files = {}
        self.folders = {}

        data = VENV_FILENAME_PATTERN.match(os.path.basename(name))
        if not data:
            raise ValueError("Not a valid versioned filename: '%s'" % name)
        self.package = data.group(1)
        self.version = data.group(2)
        self.package_ext = data.group(3)

        with tarfile.open(fileobj=fileobj, mode='r') as archive:
            for f in archive:
                if f.isreg():
                    entry_fileobj = archive.extractfile(f)
                    entry = VenvEntry(f.name, f.size, f.mode, f.uid, f.gid,
                                      entry_fileobj)
                    self.files[entry.name] = entry
                else:
                    entry = VenvFolderEntry(f.name, f.mode, f.uid, f.gid)
                    self.folders[entry.name] = entry

    def __len__(self):
        return len(self.files.keys()) + len(self.folders.keys())

    def _should_ignore(self, fname):
        """Return True if fname matches any of self.IGNORED_PATTERNS """
        for pattern in self.IGNORED_PATTERNS:
            if fnmatch.fnmatch(fname, pattern):
                return True
            return False

    def __eq__(self, other):
        if type(other) is not type(self):
            raise TypeError("%s is not %s for comparison" %
                            (type(other), type(self)))

        if self.package != other.package:
            print("Package names differ")
            return False

        for f in self.files:
            if self._should_ignore(f):
                continue

            if f not in other.files:
                print("File only in one venv: %s" % f)
                return False

            if not (self.files[f] == other.files[f]):
                print("Files don't match")
                return False

        for f in other.files:
            if self._should_ignore(f):
                continue

            if f not in self.files:
                print("File only in second venv: %s" % f)
                return False

        return True


class VenvSet(object):
    """A set of venvs"""
    def __init__(self, name, container):
        self.name = name
        self.venvs = []

        for f in container:
            print("    Processing file %s" % f.name)
            if f.isreg():
                venv = Venv(f.name, container.extractfile(f))
                self.venvs.append(venv)
            else:
                if f.name not in ["."]:
                    raise Exception("Unexpected kit structure")

    def __len__(self):
        return len(self.venvs)

    def __iter__(self):
        self.index = 0
        return self

    def next(self):
        # Needed by python 2.x
        return self.__next__()

    def __next__(self):
        try:
            result = self.venvs[self.index]
        except IndexError:
            raise StopIteration
        self.index += 1
        return result

    def __contains__(self, package):
        for venv in self.venvs:
            if venv.package == package:
                return True
        return False

    def get(self, package):
        for venv in self.venvs:
            if venv.package == package:
                return venv
        raise KeyError("Package %s not found in set %s" % (package, self.name))


class ScratchSet(VenvSet):
    """A collection of recently built venv packages"""

    def __init__(self, name, scratchpath):
        self.name = name
        venvs = collections.defaultdict(dict)

        for f in os.listdir(scratchpath):
            if not f.endswith(".tgz"):
                continue

            name = os.path.basename(f)
            path = os.path.join(scratchpath, f)

            print("    Processing file %s" % path)

            venv = Venv(name, open(path, "r"))
            venvs[venv.package][venv.version] = venv

        self.venvs = []
        for package, versions in venvs.items():
            latest_version = max(versions.keys())
            self.venvs.append(versions[latest_version])


class Kit(object):

    def __init__(self, path):
        self.venvsets = []
        self.path = path

    def get_top_level_kit(self):
        """Return deployer tarball from kit"""
        ardana_path = os.path.join(self.path, "ardana")
        if not os.path.isdir(ardana_path):
            raise(KeyError(
                "path does not contain a ardana directory: %s" % self.path))

        globs = glob.glob(os.path.join(ardana_path, "ardana-*Z.tar"))
        if len(globs) == 0:
            raise(KeyError("path does not contain a ardana kit: %s" % self.path))
        if len(globs) > 1:
            raise(KeyError(
                "path does not contain expected file structure: %s" %
                self.path))

        return globs[0]

    def append(self, venvset):
        self.venvsets.append(venvset)

    def read_hlinux_build_manifest(self):
        tarball = self.get_top_level_kit()

        name, version, build = get_top_level_kit_parts(tarball)
        buildmanifest_filename = name + '/' + name + '-build.manifest-' + build

        packages = []

        with tarfile.open(name=tarball, mode="r") as tar:
            packages = []
            try:
                buildmanifest = tar.extractfile(buildmanifest_filename)
                buildmanifest_y = yaml.load(buildmanifest)
                packages = buildmanifest_y['packages']
            except Exception:
                global BINARY_BUILD_ENVIRONMENT_MATCHES
                print(
                    "No build manifest found, assuming binaries are different")
                BINARY_BUILD_ENVIRONMENT_MATCHES = False

        return packages


class Scratch(Kit):

    def get_product_name_version(self):
        defaults_file = os.path.join(
            self.path,
            "..",
            "ansible/roles/product/defaults",
            "main.yml")
        data = yaml.load(open(defaults_file))

        return data["product_name_version"]

    def read_hlinux_build_manifest(self):
        buildmanifest_filename = os.path.join(
            self.path, "ardana-0.99.0-build.manifest")

        buildmanifest_y = yaml.load(open(buildmanifest_filename))
        packages = buildmanifest_y["packages"]

        return packages


def get_venv_lists_from_kit(path):
    venvsets = Kit(path)

    tarball = venvsets.get_top_level_kit()
    prefix, version, build = get_top_level_kit_parts(tarball)

    with tarfile.open(name=tarball, mode="r") as kittar:
        for venvstarname in VENV_TARS:
            filename = os.path.join(prefix, venvstarname)
            print("  Processing venv collection %s" % filename)
            try:
                fileobj = kittar.extractfile(filename)
                with tarfile.open(fileobj=fileobj, mode="r") as venvstar:
                    venvset = VenvSet(os.path.basename(filename), venvstar)
                    venvsets.append(venvset)
            except KeyError:
                # Not all kits have all venv tars
                pass

    return venvsets


def get_venvs_list_from_scratch(prefix):
    venvsets = Scratch(prefix)

    for subdir in SCRATCH_DIRS:
        path = os.path.join(prefix, subdir)
        scratch = ScratchSet("hlinux_venv.tar", path)
        venvsets.append(scratch)

    return venvsets


def write_output_file(name, filename, **args):
    """Write the four lists to a yaml file"""
    with open(filename, "a") as f:
        yaml.dump({name: args}, stream=f)


def diff_package_list(old_list, new_list):
    new = []
    same = []
    diffs = []
    removed = old_list[:]
    removedout = removed[:]

    for entry in new_list:
        match = False
        for e in removed:
            if entry["name"] == e["name"]:
                if (((entry["architecture"] == e["architecture"]) and
                     (entry["version"] == e["version"]))):
                    same.append(entry)
                    removedout.remove(e)
                    match = True
                    break
                else:
                    diffs.append(entry)
                    removedout.remove(e)
                    match = True
                    break
        if not match:
            new.append(entry)

    return new, same, diffs, removedout


def ignore_safe_packages(new, same, diffs, removed):
    safe = []
    for entry in new:
        if entry["name"] in SAFE_PACKAGES:
            new.remove(entry)
            safe.append(entry)
    for entry in diffs:
        if entry["name"] in SAFE_PACKAGES:
            diffs.remove(entry)
            safe.append(entry)
    for entry in removed:
        if entry["name"] in SAFE_PACKAGES:
            removed.remove(entry)
            safe.append(entry)
    return safe


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("previous", help="Previous iso mount path or tarball")
    parser.add_argument("scratch", help="Scratch area")
    parser.add_argument("--verbose", help="Verbose output",
                        action="store_true")
    parser.add_argument("--report", help="Output file for report",
                        default="venvreport.yml")
    args = parser.parse_args()

    if args.verbose:
        global VERBOSE
        VERBOSE = True

    with open(args.report, "w"):
        # Just clear the file, then we can write to it later using append
        pass

    if not check_valid_iso_kit(args.previous):
        print("Invalid previous kit")
        sys.exit(1)

    print("Collecting scratch area package list and build manifest")
    new_lists = get_venvs_list_from_scratch(args.scratch)
    new_packages = new_lists.read_hlinux_build_manifest()

    print("Collecting previous package list and hlinux build manifest")
    prev_lists = get_venv_lists_from_kit(args.previous)
    old_packages = prev_lists.read_hlinux_build_manifest()

    packages_new, packages_same, packages_diffs, packages_removed = \
        diff_package_list(old_packages, new_packages)

    safe = ignore_safe_packages(packages_new, packages_same,
                                packages_diffs, packages_removed)

    print("  New:%d same:%d diffs:%d removed:%d safe %d" %
          (len(packages_new), len(packages_same),
           len(packages_diffs), len(packages_removed),
           len(safe)))

    if args.report:
        write_output_file("dpkg build env", args.report, new=packages_new,
                          diffs=packages_diffs, same=packages_same,
                          removed=packages_removed, safe=safe)

    global BINARY_BUILD_ENVIRONMENT_MATCHES

    if (((len(packages_new) > 0) or
         (len(packages_diffs) > 0) or
         (len(packages_removed)) > 0)):
        BINARY_BUILD_ENVIRONMENT_MATCHES = False

    print("Binary build environments match: %s" %
          BINARY_BUILD_ENVIRONMENT_MATCHES)

    dupes_map = {}

    for new_venvset in new_lists.venvsets:
        new = []
        diffs = []
        dupes = {}
        removed = []

        prev_venvset = None

        dupes_map[new_venvset.name] = []

        for v in prev_lists.venvsets:
            if v.name == new_venvset.name:
                prev_venvset = v

        if prev_venvset is None:
            print("venv collection %s not in previous kit, skipping" %
                  new_venvset.name)
            continue

        for venv in prev_venvset:
            if venv.package not in new_venvset:
                removed.append(venv.package)

        for venv in new_venvset:
            if venv.package not in prev_venvset:
                new.append(venv.package)
                continue

            old = prev_venvset.get(venv.package)
            if venv == old:
                dupes[venv.package] = {
                    "previous": old.version,
                    "new": venv.version
                }
            else:
                print("package %s differs\n" % venv.package)
                diffs.append(venv.package)

        print("%d new %d different %d duplicates %d removed" %
              (len(new), len(diffs), len(dupes), len(removed)))

        if args.report:
            write_output_file(new_venvset.name, args.report, new=new,
                              diffs=diffs, dupes=dupes, removed=removed)

        print("Duplicates: %s" % (", ".join(dupes.keys())))

        dupes_map[new_venvset.name] = dupes

    print("Debug: dupes_map: %s" % dupes_map)


if __name__ == "__main__":
    main()
