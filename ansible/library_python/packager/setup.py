#!/usr/bin/env python
# (c) Copyright 2013-2016 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import setuptools


def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()


setuptools.setup(
    name="ardana-packager",
    version="0.0.3",
    description="Prepackaged virtualenv deployment tool",
    long_description=read('README.md'),
    author='SUSE LLC',
    author_email='ardana@googlegroups.com',
    # url="http://"
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Topic :: Utilities",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python",
        "Programming Language :: Python :: 2",
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Python :: 2.6",
    ],

    packages=[
        "ardana_packager",
    ],
    package_data={
        "ardana_packager": ["*.yml"],
    },

    entry_points={
        'console_scripts': [
            'install_package = ardana_packager.cmd:main',
            'create_index = ardana_packager.indexer:main',
            'setup_systemd = ardana_packager.setup_systemd:main',
            'venv_edit = ardana_packager.venv_edit:main',
            'config_symlinks = ardana_packager.symlinks:main',
        ],
    },
    install_requires=[
        "PyYAML>=3.11",
        "requests>=2.4.3",
        "six",
        ],
)
