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

import re

import jinja2.runtime as jrt


def findall(data, pattern, *args, **kwargs):
    """Search the input for a given pattern and return any matches found

    If a match cannot be found, return a default instead, otherwise an
    empty string
    """
    default = kwargs.get('d', jrt.StrictUndefined())
    default = kwargs.get('default', default)

    try:
        matches = re.findall(pattern, data)
        yield matches
    except TypeError:
        if not isinstance(default, jrt.StrictUndefined):
            yield default


class FilterModule(object):
    def filters(self):
        return {'findall': findall}
