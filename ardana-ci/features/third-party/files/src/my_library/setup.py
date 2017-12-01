#!/usr/bin/env python

# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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


# parse_requirements() returns generator of pip.req.InstallRequirement objects
with open(os.path.join(os.path.dirname(__file__), 'requirements.txt')) as f:
    reqs = [i.strip() for i in f.readlines()]

setuptools.setup(
    name="my_library",
    version="0.0.1",
    description="Example library for injecting into a venv",
    long_description=read('README.md'),
    author="Hewlett-Packard Enterprise Development L.P.",
    # author-email=""
    # url="http://"
    classifiers=[
        "Development Status :: 1 - Alpha",
        "Topic :: Utilities",
        "License :: OSI Approved :: Apache License",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python",
        "Programming Language :: Python :: 2",
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Python :: 2.6",
    ],

    packages=[
        "my_library",
    ],

    install_requires=reqs,
)
