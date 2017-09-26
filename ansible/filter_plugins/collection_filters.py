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
# these provide common filters to easily extract subsets of data
# from multi level dictionaries including matching on the names
# of keys.
#

import itertools

import jinja2.runtime as jrt


def do_flatten(lists):
    """Flatten multiple lists

    Takes a list of lists and returns a single list of the contents.
    """

    for item in itertools.chain.from_iterable(lists):
        yield item


def do_reduce(collection, *args, **kwargs):
    """Extract multi-level attributes from collection

    Return a generator of the results from the given attributes in the
    provided collection.

    So for multiple dictionaries such as:
        collection = [
            {'attr': {'data': 1}},
            {'attr': {'data': 2}},
            {'attr': {'data': 3}}
        }

        so `do_reduce(collection, 'attr', 'data')` yields `1, 2, 3`
    """
    default = kwargs.get('d', jrt.StrictUndefined())
    default = kwargs.get('default', default)
    for item in collection:
        try:
            yield reduce(type(item).__getitem__, args, item)
        except (KeyError, TypeError):
            if not isinstance(default, jrt.StrictUndefined):
                yield default


def do_collect(collection, needles):

    for item in needles:
        try:
            yield collection[item]
        except KeyError:
            pass


class FilterModule(object):

    def filters(self):
        return {'flatten': do_flatten,
                'collect': do_collect,
                'reduce': do_reduce}
