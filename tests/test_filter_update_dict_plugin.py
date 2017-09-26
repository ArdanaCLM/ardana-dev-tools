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

import tests.filters_base  # noqa

from oslotest import base
import update_dict


class TestUpdateDict(base.BaseTestCase):

    def test_simple(self):
        d = update_dict.update({}, {1: 2})
        self.assertDictEqual(d, {1: 2})

        d = update_dict.update({1: 3}, {1: 2})
        self.assertDictEqual(d, {1: 2})

    def test_rescursive(self):
        d = update_dict.update({1: 2}, {1: {2: 4}})
        self.assertDictEqual(d, {1: {2: 4}})

        d = update_dict.update({1: {2: 3}}, {1: {2: 4}})
        self.assertDictEqual(d, {1: {2: 4}})

        d = update_dict.update({1: {2: 3, 3: 4}}, {1: {2: 4}})
        self.assertDictEqual(d, {1: {2: 4, 3: 4}})
