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

from oslotest import base

import create_dpkg_diff_list


class DpkgTest(base.BaseTestCase):

    def test_basic(self):
        list1 = ["foo.deb", "bar.deb", "baz.deb"]
        list2 = ["foo2.deb", "zod.deb", "bar.deb"]

        new, dupes, removed = create_dpkg_diff_list.diff_package_list(
            list1, list2)

        # new list wrong
        self.assertEqual(new, ['foo2.deb', 'zod.deb'])
        # removed list wrong
        self.assertEqual(removed, ['foo.deb', 'baz.deb'])
        # Dupes list wrong
        self.assertEqual(dupes, ['bar.deb'])
