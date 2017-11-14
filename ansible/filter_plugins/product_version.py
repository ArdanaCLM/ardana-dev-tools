#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
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
import os.path
import re


def parse_tarball_version(tarball):
    filename = os.path.basename(tarball)
    matcher = re.compile(
        "(?P<version>\w+-\d+.\d+.\d+(.[a-zA-Z0-9]+|)"
        "(-([a-z])*(\d+)?(.\d+)*)?)"
        "\-[0-9TZ]+.t[a-z][a-z]")
    matched = matcher.match(filename)
    if not matched:
        raise Exception("No deployer version found")
    return matched.groupdict()["version"]


def test_parse_tarball_version():
    assert (parse_tarball_version('ardana-0.2.0-b.2-20150923T113920Z.tgz')
            == 'ardana-0.2.0-b.2')
    assert (parse_tarball_version('ardana-0.2.0-rc1-20150923T113920Z.tgz')
            == 'ardana-0.2.0-rc1')
    assert (parse_tarball_version('ardana-0.2.0-rc1.1-20150923T113920Z.tgz')
            == 'ardana-0.2.0-rc1.1')
    assert (parse_tarball_version('ardana-0.2.0-20150923T113920Z.tgz')
            == 'ardana-0.2.0')
    assert (parse_tarball_version('ardana-0.2.2-20150923T113920Z.tgz')
            == 'ardana-0.2.2')
    assert (parse_tarball_version('ardana-0.2.2-1-20150923T113920Z.tgz')
            == 'ardana-0.2.2-1')


class FilterModule(object):

    def filters(self):
        return {
            "parse_tarball_version": parse_tarball_version
        }


if __name__ == '__main__':
    test_parse_tarball_version()
