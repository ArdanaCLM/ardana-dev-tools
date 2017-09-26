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
"""
The configuration handler.
"""

import collections
import re

try:
    # 2-to-3 preempt
    import ConfigParser as configparser
except ImportError:
    import configparser

CONFIG = '/etc/packager.conf'
_CACHE_DIR = '/var/cache/ardana_packager'
_VENV_LOCATION = '/opt/stack/venv'
_SERVICE_LOCATION = '/opt/stack/service'
PACKAGE_FILE = 'packages'

# Let's fix this format up.
_format = r'''^  ( \w+ (?: -\w+ )* )
                 -
                 (
                   (?:
                     ardana - \d+ (?: \.\d+ )*
                   )
                   |
                   (?:
                     [0-9a-zA-Z]+
                   )
                 )'''.replace(' ', '').replace('\n', '')

TAR_FORMAT = re.compile(_format + '\\.tgz$')
DIR_FORMAT = re.compile(_format + '$')

VERSION_LATEST = object()


class Config(collections.MutableMapping):
    def __init__(self, file=CONFIG, *args, **kwargs):
        self._config = configparser.SafeConfigParser()
        self._config.read(file)
        self._dict = kwargs

    @property
    def repo_url(self):
        """Return the configured repo location

        Ensure that it ends with a '/' character.
        """
        url = self._config.get("repo", "url")
        if url.endswith('/'):
            return url
        return url + '/'

    @property
    def VENV_LOCATION(self):
        try:
            return self._config.get("install", "dir")
        except Exception:
            return _VENV_LOCATION

    @property
    def SERVICE_LOCATION(self):
        try:
            return self._config.get("components", "dir")
        except Exception:
            return _SERVICE_LOCATION

    @property
    def CACHE_DIR(self):
        try:
            return self._config.get("install", "cache")
        except Exception:
            return _CACHE_DIR

    # Implementing the following gives us the whole MutableMapping interface

    def __getitem__(self, *args, **kwargs):
        return self._dict.__getitem__(*args, **kwargs)

    def __setitem__(self, *args, **kwargs):
        return self._dict.__setitem__(*args, **kwargs)

    def __delitem__(self, *args, **kwargs):
        return self._dict.__delitem__(*args, **kwargs)

    def __iter__(self, *args, **kwargs):
        return self._dict.__iter__(*args, **kwargs)

    def __len__(self, *args, **kwargs):
        return self._dict.__len__(*args, **kwargs)
