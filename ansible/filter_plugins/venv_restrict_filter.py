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
# Usage :
#   sources=[nova:{}, ironicclient:{}, swift:{}],
#   packages=[nova],
#   services={nova:{sources:[nova,ironicclient]}}
#     | venv_restrict
#       => [[nova,{}], [ironicclient,{}]]

import os.path


def venv_restrict(sources, packages, services):
    output = []
    req_sources = set()
    for package in packages:
        for source in services[package].get('sources', []):
            if isinstance(source, dict):
                req_sources.update(source.keys())
            else:
                req_sources.add(source)

    for req_source in req_sources:
        data = sources[req_source].copy()
        data["name"] = req_source
        output.append(data)

    return output


def venv_sources_by_packages(sources, packages, services):
    output = {}
    found_sources = set()
    for package in packages:
        output[package] = []
        for source in services[package].get('sources', []):
            if isinstance(source, dict):
                required_sources = source.keys()
            else:
                required_sources = [source]

            for src in required_sources:
                if src in packages and src != package:
                    # keep sources grouped with their primary
                    # package if possible
                    continue

                if src not in found_sources:
                    data = sources[src].copy()
                    data["name"] = src
                    output[package].append(data)
                    found_sources.add(src)

    return output


# Usage:
#  copy_dict(*attributes_to_keep)

def copy_dict(d, *attributes):
    return {k: {a: d[k].get(a, None) for a in attributes}
            for k in d}


# 'python-keystoneclient' | venv_packagify =>
# [Pp][Yy][Tt][Hh][Oo][Nn][-_][Kk]...[Tt]
# Used to turn a source name into something that's likely
# to match a package filename using shell glob syntax.

def packagify(string):
    result = ''
    for char in string:
        if char.isalpha():
            result += '[' + char.upper() + char.lower() + ']'
        elif char in '-_':
            result += '[-_]'
        else:
            result += char
    return result


# From the source return the destination on the build machine
def venv_source_build_dest(source):
    # sync_dir first, then url, then src
    url = source.get("sync_dir", source.get("url", source.get("src")))
    if not url:
        raise Exception(
            "Can't find destination on build machine without url or src")

    return os.path.basename(url.rstrip("/"))


# From the source return the package name
# This differs manly from venv_source_build_dest in that
# we ignore the sync_dir option to a source
def venv_source_build_name(source):
    url = source.get("url", source.get("src"))
    if not url:
        raise Exception("Can't find source name")

    return os.path.basename(url.rstrip("/"))


class FilterModule(object):
    def filters(self):
        return {'venv_restrict': venv_restrict,
                'venv_copy_dict': copy_dict,
                'venv_packagify': packagify,
                'venv_sources_by_packages': venv_sources_by_packages,
                'venv_source_build_dest': venv_source_build_dest,
                'venv_source_build_name': venv_source_build_name}
