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
# A simple script that looks for duplicate filenames in the list
# supplied on the command line. Note that I call glob on each arg
# which allows the user to supply glob patterns that will be expanded
# inside this script, instead of having the shell do it up front.
# This is useful because most shells have a fairly small limit on
# the total length of a command line. If you are supplying glob
# patterns then make sure to quote them, otherwise the shell will do
# the expansion in advance and that defeats the purpose.

import glob
import os
import sys

# Filenames that we want to ignore... exact content tbd.
# For example if all directories contain a README we might
# want to ignore that.
ignore = ()

retval = 0


def report_error(lst):
    global retval
    print("ERROR: Namespace collision:")
    for item in lst:
        print("  %s" % item)
    retval = 1


def dedup(filelist):
    history = dict()
    for item in filelist:
        name = os.path.basename(item)
        if name in ignore:
            continue
        if name in history:
            history[name] += [item]
        else:
            history[name] = [item]
    for name, lst in history.iteritems():
        if len(lst) > 1:
            report_error(lst)

allfiles = []
for g in sys.argv[1:]:
    allfiles += glob.glob(g)

dedup(allfiles)
exit(retval)
