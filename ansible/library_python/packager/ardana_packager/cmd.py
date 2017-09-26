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

import json
import six
import sys

import ardana_packager.activate as activate
import ardana_packager.ansible as ansible
import ardana_packager.cache as cache
import ardana_packager.config as config
from ardana_packager.error import InstallerError
import ardana_packager.expand as expand
import ardana_packager.service as service
from ardana_packager.version import Spec


def main():
    # This must be called from a module with WANT_JSON specified
    with open(sys.argv[1]) as f:
        params = {'state': None,
                  'name': None,
                  'group': 'root',
                  'extra_mode_bits': '000',
                  'service': None,
                  'version': config.VERSION_LATEST,
                  'suffix': None,
                  'cache': None,
                  'clean': False,
                  'activate': None,
                  }
        params.update(json.load(f))
        # We make an "empty" module as the ansible module doesn't
        # have bare fail_json, etc, functions.
        module = ansible.AnsibleModule(argument_spec={}, args=[])

    state = params['state']
    assert state in ('present', 'absent', None)
    name = params['name']
    group_name = params['group']
    extra_mode_bits = int(params['extra_mode_bits'], 8)
    service_name = params['service']
    version = params['version']
    suffix = params['suffix']
    cache_op = params['cache']
    assert cache_op in ('update', None)
    clean = params['clean']
    activate = params['activate']
    assert activate in ('act_on', 'act_off', None)

    # Backward-compatible argument munging: sometimes "version"
    # really means "suffix".
    if isinstance(version, dict):
        assert version['v'] == 1
        if suffix is None:
            suffix = version['suffix']
        version = version['version']

    elif activate == 'act_on' and state is None:
        if suffix is None and isinstance(version, six.string_types):
            # Use the suffix
            suffix = version
            version = None

    if activate is None:
        activate = 'act_on'

    spec = Spec(package=name, service=service_name,
                version=version, suffix=suffix)

    conf = config.Config(group_name=group_name,
                         extra_mode_bits=extra_mode_bits)

    # For the moment ...
    # TODO(jan) break this out into a class that can control it all.
    changed = False

    if cache_op == "update":
        try:
            changed = cache.update(conf) or changed
        except Exception as e:
            module.fail_json(msg="Installation failed",
                             name=name,
                             group=group_name,
                             extra_mode_bits=extra_mode_bits,
                             service=service_name,
                             version=_report_version(version),
                             exception=str(e))
            return

    elif state == "present":
        try:
            (changed_ret, spec) = install(spec, conf)
            changed = changed or changed_ret
        except InstallerError as e:
            module.fail_json(msg="Installation failed",
                             name=name,
                             group=group_name,
                             extra_mode_bits=extra_mode_bits,
                             service=service_name,
                             version=_report_version(spec.version),
                             exception=str(e))
            return
    elif state == "absent":
        try:
            (changed_ret, spec) = uninstall(spec, conf)
            changed = changed or changed_ret
        except InstallerError as e:
            module.fail_json(msg="Installation failed",
                             name=name,
                             service=service_name,
                             version=str(spec.version),
                             exception=str(e))
            return

    if clean:
        # TODO(jang)
        pass

    # activate defaults to act_on but if we are removing package then
    # we can't activate it
    if state != 'absent' and activate == "act_on" \
       and name is not None and service_name is not None:
        try:
            (changed_ret, version) = activate_install(spec, conf)
        except InstallerError as e:
            module.fail_json(msg="Activation failed",
                             name=name,
                             service=service_name,
                             version=str(spec.version),
                             exception=str(e))
            return

    version = _report_version(spec.version)

    try:
        suffix = spec.suffix
    except AttributeError:
        suffix = None

    _version = {'version': version,
                'suffix': spec.suffix if hasattr(spec, 'suffix') else suffix,
                'v': 1,
                }

    module.exit_json(state=state, name=name, group=group_name,
                     extra_mode_bits=extra_mode_bits, service=service_name,
                     package_version=str(spec.version), suffix=suffix,
                     # version should be deprecated - replace
                     # with package_version or suffix
                     version=_version,
                     cache=cache_op, clean=clean,
                     changed=changed)


def _report_version(version):
    if version is cache.VERSION_LATEST:
        return None
    return str(version)


def install(spec, conf):
    (changed, spec) = expand.explode(conf, spec)
    changed = service.refer(conf, spec) or changed
    current_version = activate.active_version(conf.SERVICE_LOCATION, spec)
    changed = service.refer(conf, spec) or changed
    if current_version == spec.version:
        changed = False
    return (changed, spec)


def uninstall(spec, conf):
    changed = False
    current_version = activate.active_version(conf.SERVICE_LOCATION, spec)
    if current_version is not None and (spec.version is config.VERSION_LATEST
                                        or current_version == spec.version):
        spec.version = current_version
        activate.deactivate(conf.SERVICE_LOCATION, spec)
        changed = True
    changed = service.remove(conf, spec) or changed
    if not service.count_refs(conf, spec):
        changed = expand.remove(conf, spec) or changed
    return (changed, spec)


def activate_install(spec, conf):
    current_version = activate.active_version(conf.SERVICE_LOCATION, spec)
    if current_version == spec.version:
        return (False, spec)
    if current_version is not None:
        activate.deactivate(conf.SERVICE_LOCATION,
                            Spec(package=spec.package, service=spec.service,
                                 version=current_version))
        # Leaving removal of service venv until separate cleanup phase
        # service.remove(conf, spec, current_version)
    activate.activate(conf.SERVICE_LOCATION, spec)
    # TODO(howleyt): should we differentiate between new vs. old version?
    return (True, spec)
