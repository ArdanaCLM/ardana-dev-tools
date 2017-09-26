#!/usr/bin/env python
#
# (c) Copyright 2015 Hewlett Packard Enterprise Development LP
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
import os
import sys
import yaml

retval = 0


def report_error(lst):
    global retval
    print("ERROR: yaml syntax error:")
    for item in lst:
        print("  %s" % item)
    retval = 1


def check_content(data):
    # ... we may add actual tests here in the future ...
    # ... they would call report_error on failure ...
    pass


def parse(fname):
    try:
        data = yaml.safe_load(open(fname, 'r'))
        check_content(data)
    except yaml.constructor.ConstructorError as e:
        report_error([str(e), ])
    except yaml.scanner.ScannerError as e:
        report_error([str(e), ])


def walk(tree):
    for dirname, subdirs, files in os.walk(tree):
        for f in files:
            if f.endswith('.yml'):
                parse(os.path.join(dirname, f))


if __name__ == "__main__":
    retval = 0
    if len(sys.argv) > 1:
        for pathname in sys.argv[1:]:
            if os.path.isdir(pathname):
                walk(pathname)
            else:
                parse(pathname)
    else:
        walk('.')
    exit(retval)
