#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
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
        v_a = hash_a.get(k_b)
        # If both are dicts, merge recursively
        if isinstance(v_b, dict) and isinstance(v_a, dict):
            v_b = update(v_a, v_b)
        # If both are lists, concatenate
        elif isinstance(v_b, list) and isinstance(v_a, list):
            v_b = v_a + v_b
        new[k_b] = v_b
    return new


class FilterModule(object):

    def filters(self):
        return {'update': update}
