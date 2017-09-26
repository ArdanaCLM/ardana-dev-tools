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

import hashlib
import os
import os.path
import urlparse


_DEFAULT_BASE = os.path.join(os.environ["HOME"], ".cache-ardana/sources/")
BASE = os.environ.get("ARDANA_SOURCE_CACHE_DIR", _DEFAULT_BASE)


def _cache_path(source, subdir):
    if isinstance(source, dict):
        url = source["url"]
        sync_dir = source.get("sync_dir")
        if sync_dir:
            url = sync_dir
    else:
        url = source

    c_name = hashlib.sha1(os.path.dirname(url)).hexdigest()
    c_path = "%s/%s/%s_%s" % (BASE, subdir, os.path.basename(url), c_name)

    return c_path


def bare_cache_path(source):
    return "%s.git" % _cache_path(source, "bare")


def branched_cache_path(source, branch=None):
    branch = branch or source["branch"]
    return _cache_path(source, branch.replace("/", "-"))


# This is now only used for managing the external URL content that
# we package up and diskimage-builder.
def cache_path(url, base, alternative=None):
    if alternative:
        url = alternative

    c_name = hashlib.sha1(url).hexdigest()
    c_path = "%s/%s_%s" % (base, os.path.basename(url), c_name)

    return c_path


def external_artifact_url(item, site_config):
    base_url = site_config.get(
        "ardana_artifacts_host", "http://ardana.suse.provo.cloud")

    return urlparse.urljoin(base_url, item["path"])


def find_local_repo(source):
    """Return the full path on the developers machine to the source

    If a local checkout has been performed for this source, then return the
    full absolute path to this directory. Otherwise return the absolute path
    to the locally cached repository.
    """
    sources_dir = os.path.normpath(__file__ + '/../../../..')

    src = source.get("src", None)
    if src:
        return src

    url = source["url"]

    local_source = os.path.join(sources_dir, os.path.basename(url))
    if os.path.exists(local_source):
        return local_source

    return branched_cache_path(source, source["branch"])


class FilterModule(object):

    def filters(self):
        return {"cache_path": cache_path,
                "external_artifact_url": external_artifact_url,
                "find_local_repo": find_local_repo,
                "bare_cache_path": bare_cache_path,
                "branched_cache_path": branched_cache_path}
