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

from jinja2 import filters
import pkg_resources


@filters.contextfilter
def do_check_specs(*args, **kwargs):
    context = args[0]
    values = args[1]
    pkgs = args[2]

    func = lambda item, args: context.environment.call_filter(
        'version_compare_smart', item, args, kwargs, context=context)

    specs_dict = {pkg['name'].lower(): pkg['specs'] for pkg in pkgs}
    for value in values:
        name, version = [s for s in value.split('=') if s]
        if name.lower() in specs_dict:
            yield all(func(version, (req_version, op))
                      for (op, req_version) in specs_dict[name.lower()])


def do_parse_requirements(value, package=None):
    for req in pkg_resources.parse_requirements(value):
        if package is not None:
            if req.project_name == package:
                yield req.specs
        else:
            yield {'name': req.project_name, 'specs': req.specs}


class FilterModule(object):
    def filters(self):
        return {
            "parse_requirements": do_parse_requirements,
            "check_specs": do_check_specs,
        }
