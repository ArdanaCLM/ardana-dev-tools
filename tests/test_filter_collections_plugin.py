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

from oslotest import base

import tests.filters_base  # noqa

from collection_filters import do_collect
from collection_filters import do_flatten
from collection_filters import do_reduce


class FlattenTests(base.BaseTestCase):

    def test_simple(self):
        list1 = [{'ab': {'ac': 1}},
                 {'bb': {'bc': 2}}]
        list2 = [{'cb': {'cc': 3}}]

        flatlist = [
            {'ab': {'ac': 1}},
            {'bb': {'bc': 2}},
            {'cb': {'cc': 3}}
        ]

        self.assertEqual(list(do_flatten([list1, list2])), flatlist)


class ReduceTests(base.BaseTestCase):

    def test_simple(self):
        collection = [
            {'a': {'b': 1}},
            {'a': {'b': 2}},
            {'a': {'b': 3}}
        ]

        self.assertEqual(list(do_reduce(collection, 'a', 'b')), [1, 2, 3])
        self.assertEqual(list(do_reduce(collection, 'a', 'd')), [])

    def test_defaults(self):
        collection = [
            {'a': {'b': 1}},
            {'a': {'b': 2}},
            {'a': {'c': 3}}
        ]

        self.assertEqual(list(do_reduce(collection, 'a', 'b', default=99)),
                         [1, 2, 99])
        self.assertEqual(list(do_reduce(collection, 'a', 'd', default=99)),
                         [99, 99, 99])


class CollectTests(base.BaseTestCase):

    def test_simple(self):
        collection = {
            'a': {'ab': {'ac': 1}},
            'b': {'bb': {'bc': 2}},
            'c': {'cb': {'cc': 3}}
        }

        self.assertItemsEqual(
            list(do_collect(collection, ['a', 'c'])),
            [v for k, v in collection.items() if k != 'b'])
        self.assertItemsEqual(
            list(do_collect(collection, ['a', 'b', 'c'])),
            collection.values())
        self.assertItemsEqual(
            list(do_collect(collection, ['a', 'b', 'c', 'd'])),
            collection.values())
