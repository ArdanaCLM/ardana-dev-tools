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

import yaml


class FilterModule(object):
    '''Additional yaml filters'''

    def filters(self):
        return {
            'to_multi_yaml': yaml.safe_dump_all,
            # some programs output yaml where they add comments before
            # the document start marker. This allows you to convert
            # the entire output
            'from_multi_yaml': yaml.safe_load_all,
        }
