#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017-2018 SUSE LLC
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
import getpass
import os
import os.path
import subprocess

from ardana_packager.ansible import AnsibleModule
#  Args to this module
#    Required:
#      service:  The name of the service (e.g. nova-api, swift-proxy, etc.)
#      cmd:  The command to use to invoke the service (e.g. keystone-all)
#
#    Optional:
#      name: The systemd unit name
#            Default: service
#      install_dir:  The directory where the service is installed
#                    Default: /opt/stack/service
#      user:  The user name under which the service should run
#             Default: stack
#      group: The group in which the service should belong
#             Default: user
#      args:  Any arguments to cmd
#             Default: None
#      type:  Configures process start-up type for the services
#             Default: simple

# Location of systemd system dir
SYSTEMD_DIR = "/etc/systemd/system"
SYSTEMCTL = "/bin/systemctl"


def main():
    module = AnsibleModule(
        argument_spec=dict(
            service=dict(required=True),
            cmd=dict(required=True),
            name=dict(default=None),
            install_dir=dict(default="/opt/stack/service"),
            install_path=dict(default=None),
            user=dict(default=getpass.getuser()),
            group=dict(default=None),
            args=dict(default=None),
            env=dict(default={}),
            type=dict(default="simple"),
            restart=dict(default=""),
            restart_sec=dict(default=""),
            stdout=dict(default="journal"),
            stderr=dict(default="inherit"),
            # Service enablement stuff
            enable=dict(default=None),
            before=dict(default=""),
            after=dict(default=""),
            wants=dict(default=""),
            wanted_by=dict(default=""),
            limit_open_files=dict(default=""),
        ),
        supports_check_mode=False
    )

    params = module.params
    service = params['service']
    cmd = params['cmd']
    name = params['name'] or service
    install_dir = params['install_dir']
    install_path = params['install_path']
    if install_path is None:
        install_path = "%s/%s/venv/bin" % (install_dir, service)
    user = params['user']
    group = params['group'] or user
    args = params['args']
    startup_type = params['type']
    env = params['env']
    restart = params['restart']
    restart_sec = params['restart_sec']
    stdout = params["stdout"]
    stderr = params["stderr"]

    enable = params['enable']
    before = params['before']
    after = params['after']
    wants = params['wants']
    wanted_by = params['wanted_by']
    limit_open_files = params['limit_open_files']

    changed = False

    try:
        changed = write_systemd(service, cmd, name,
                                install_path, user, group,
                                args=args, startup_type=startup_type,
                                env=env, restart=restart,
                                restart_sec=restart_sec, before=before,
                                after=after, wants=wants, wanted_by=wanted_by,
                                stdout=stdout, stderr=stderr,
                                limit_open_files=limit_open_files)
    except Exception as e:
        module.fail_json(msg="Write systemd failed",
                         service=service,
                         cmd=cmd,
                         name=name,
                         install_dir=install_dir,
                         install_path=install_path,
                         user=user,
                         group=group,
                         args=args,
                         startup_type=startup_type,
                         env=env,
                         restart=restart, restart_sec=restart_sec,
                         before=before,
                         after=after,
                         wants=wants,
                         wanted_by=wanted_by,
                         limit_open_files=limit_open_files,
                         enable=enable,
                         exception=str(e))
        return

    if systemd_daemon_reload() != 0:
        module.fail_json(msg="systemctl daemon-reload failed",
                         service=service,
                         cmd=cmd,
                         name=name,
                         install_dir=install_dir,
                         install_path=install_path,
                         user=user,
                         group=group,
                         args=args,
                         restart=restart, restart_sec=restart_sec,
                         startup_type=startup_type,
                         limit_open_files=limit_open_files)
        return

    if type(enable) is bool:
        retcode, changed_2 = systemd_daemon_enable(name, enable)
        changed = changed or changed_2
        if retcode != 0:
            module.fail_json(msg="systemctl enable failed",
                             service=service,
                             cmd=cmd,
                             name=name,
                             install_dir=install_dir,
                             install_path=install_path,
                             user=user,
                             group=group,
                             args=args,
                             startup_type=startup_type,
                             env=env,
                             restart=restart, restart_sec=restart_sec,
                             before=before,
                             after=after,
                             wants=wants,
                             wanted_by=wanted_by,
                             limit_open_files=limit_open_files,
                             enable=enable)

    module.exit_json(service=service, cmd=cmd, name=name,
                     install_dir=install_dir, install_path=install_path,
                     user=user, group=group, args=args,
                     startup_type=startup_type, env=env, restart=restart,
                     restart_sec=restart_sec, enable=enable, before=before,
                     after=after, wants=wants, wanted_by=wanted_by,
                     limit_open_files=limit_open_files,
                     changed=changed)


def write_systemd(service, cmd, name, install_path, user, group,
                  args="", startup_type="", env={}, restart="",
                  restart_sec="", before="", after="",
                  wants="", wanted_by="", stdout="journal", stderr="inherit",
                  limit_open_files=None):
    # Format env vars into X=Y space separated string
    env_str = ' '.join(('{0}={1}'.format(k, v)) for k, v in env.iteritems())

    #
    #  Make string with file contents
    #

    # NOTE(gyee): Restart parameters cannot be an empty string or systemd will
    # perpetually complain about invalid format. Therefore, we only set
    # Restart and RestartSec if services set them.
    restart_params = ""
    if restart:
        restart_params += "Restart=%s\n" % (restart)
    if restart_sec:
        restart_params += "RestartSec=%s\n" % (restart_sec)

    limit_params = ""
    if limit_open_files:
        limit_params += "LimitNOFILE=%s\n" % (limit_open_files)

    s = ("[Unit]\n"
         "Description={name} Service\n"
         "Wants={wants}\n"
         "Before={before}\n"
         "After={after}\n"
         "\n"
         "[Service]\n"
         "Type={startup_type}\n"
         "ExecStart={install_path}/{cmd} {args}\n"
         "Environment={env}\n"
         "User={user}\n"
         "Group={group}\n"
         "{restart_params}"
         "PermissionsStartOnly=true\n"
         "{limit_params}"
         "\n"
         "RuntimeDirectory={name}\n"
         "RuntimeDirectoryMode=0755\n"
         "\n"
         "StandardOutput={stdout}\n"
         "StandardError={stderr}\n"
         "\n"
         "[Install]\n"
         "WantedBy=multi-user.target {wanted_by}\n").format(
             service=service,
             cmd=cmd,
             name=name,
             install_path=install_path,
             user=user,
             group=group,
             args=args,
             startup_type=startup_type,
             env=env_str,
             restart_params=restart_params,
             limit_params=limit_params,
             wants=wants,
             wanted_by=wanted_by,
             before=before,
             after=after,
             stdout=stdout,
             stderr=stderr)

    return file_write_check(s, name)


def file_write_check(s, name):
    service_file = os.path.join(SYSTEMD_DIR, "%s.service" % name)

    # Check if systemd file exists
    if (os.path.isfile(service_file)):
        with open(service_file, "r") as fd:
            if s == fd.read():
                return False

    if not os.path.isdir(SYSTEMD_DIR):
        os.mkdir(SYSTEMD_DIR)

    with open(service_file, "w") as fd:
        fd.write(s)

    return True


def systemd_daemon_reload():
    return subprocess.call([SYSTEMCTL, "daemon-reload"])


def systemd_daemon_enable(name, enable):
    enabled = subprocess.call([SYSTEMCTL, "is-enabled", name]) == 0
    if enable and not enabled:
        return subprocess.call([SYSTEMCTL, "enable", name]), True
    elif not enable and enabled:
        return subprocess.call([SYSTEMCTL, "disable", name]), True
    else:
        return 0, False
