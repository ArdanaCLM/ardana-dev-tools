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
# Create a dict update filter


def update(hash_a, hash_b):
    new = dict(hash_a)
    for k_b, v_b in hash_b.items():
        if isinstance(v_b, dict):
            # v_b is a dict. if v_a is also a dict then
            # then merge recursively
            v_a = hash_a.get(k_b)
            if isinstance(v_a, dict):
                v_b = update(v_a, v_b)
        new[k_b] = v_b
    return new


class FilterModule(object):

    def filters(self):
        return {'update': update}
