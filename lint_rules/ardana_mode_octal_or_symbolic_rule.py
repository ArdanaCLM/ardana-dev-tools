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
import sys

from ansiblelint import AnsibleLintRule


class ArdanaModeOctalOrSymbolicRule(AnsibleLintRule):
    id = 'ARDANAANSIBLE0011'
    shortdesc = 'mode must be symbolic, variable or a 4-digit octal'
    description = ('mode when specified for file, copy and template tasks, '
                   'must be symbolic (e.g. "u=rw,g=r,o=r"), '
                   'a variable (e.g. "{{ mode }}") '
                   'or a 4-digit octal (e.g. 0700, "0700")')
    tags = ['formatting']
    _commands = ['file', 'copy', 'template']
    _ignore_states = ['absent', 'link']

    @staticmethod
    def validate_mode(mode):
        # convert symbolic to octal
        def rwx_to_oct(string):
            retval = 0
            for match, decimal in zip('rwx', [4, 2, 1]):
                retval += decimal if match in string else 0
            return retval
        matched = re.match("u=([rwx]+),g=([rwx]+),o=([rwx]+)", mode)
        if matched:
            mode = "0" + ''.join(str(rwx_to_oct(i)) for i in matched.groups())

        matched = re.match("0([4567])([04567])([04567])", mode)
        if not matched:
            return True
        user, group, other = (int(i) for i in matched.groups())

        if user < group or group < other:
            return True
        return False

    def matchtask(self, file, task):
        if sys.modules['ardana_noqa'].skip_match(file):
            return False
        action = task["action"]
        if action["module"] in self._commands:
            if action.get("state") in self._ignore_states:
                return False
            if "mode" not in action:
                return True
            mode = action.get("mode")
            if isinstance(mode, int):
                mode = "%04o" % mode
            if not isinstance(mode, str):
                return True
            if mode.startswith("{{"):
                return False
            return self.validate_mode(mode)


# ansible-lint expects the filename and class name to match
# Python style expects filenames to be all lowercase
# Python style expects classnames to be CamelCase
# Resolution: trick ansible lint with this class
class ardana_mode_octal_or_symbolic_rule(ArdanaModeOctalOrSymbolicRule):
    pass
