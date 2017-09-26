#
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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

import argparse
import os
import pipes
import re
import select
import shlex
import shutil
import socket
import subprocess
import sys
import time
import yaml

import paramiko

# Unbuffer output
sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)
sys.stderr = os.fdopen(sys.stderr.fileno(), 'w', 0)

NEWLINE = re.compile("\r?\n")


class TestPlanAction(object):

    def __init__(self, ssh_config="astack-ssh-config",
                 deployer_node="server1"):
        self.cfg = paramiko.SSHConfig()
        self.cfg.parse(open(ssh_config))

        self.ssh_config = ssh_config
        self.deployer_node = deployer_node
        self.deployer_user = self.config(self.deployer_node)["user"]

        self.client = self.connect(deployer_node)

        self.name = None
        self.log_filename = None
        self.log_prefix = None
        self.log = None
        self._first_write = True

        self.filename = None
        self.testdata = None

    def config(self, server):
        return self.cfg.lookup(server)

    def connect(self, node):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        hostinfo = self.cfg.lookup(node)

        client.connect(
            hostinfo["hostname"],
            username=hostinfo["user"],
            key_filename=hostinfo["identityfile"])

        return client

    def get_scratchdir(self):
        return os.path.expanduser(
            "/home/%s/scratch/ansible/next/ardana/ansible" % self.deployer_user)

    def get_testdir(self):
        return os.path.expanduser("/home/%s/ardana-ci-tests" % self.deployer_user)

    def set_loginfo(self, name, filename, prefix=None):
        if self.log:
            self.log.close()

        self.name = name

        if "/" in filename:
            raise Exception(
                "We don't support filenames with directory location")

        # Jenkins integration, make sure that we work with the jenkins
        # log publishers
        if os.environ.get("WORKSPACE", None):
            self.log_filename = os.path.join(os.environ["WORKSPACE"], filename)
        else:
            self.log_filename = filename

        self.log = open(filename, "w")
        self.log_prefix = prefix

    def log_data(self, data):
        if self.log_prefix:
            prefix = "\n%s: " % self.log_prefix
            if self._first_write:
                data = "%s: %s" % (self.log_prefix, data)
            data = NEWLINE.sub(prefix, data)

        sys.stdout.write(data)
        if self.log:
            self.log.write(data)

        self._first_write = False

    def _run_cmd_locally(self, shell_cmd, cwd=None, env={}):
        self.log_data("Running '%s'\n" % (shell_cmd))

        env["HOME"] = os.environ["HOME"]
        env["PYTHONUNBUFFERED"] = "1"
        for key, val in os.environ.items():
            if key.startswith("ARDANA"):
                env[key] = val

        devbin = os.path.dirname(__file__) + "/../"
        testdir = os.path.dirname(self.filename)

        env["PATH"] = "%s:%s:%s" % (
            testdir,
            devbin,
            "/usr/local/bin:/usr/bin:/bin:")

        self.log_data("  ENV: %s\n" % env)

        if not cwd:
            cwd = testdir

        cmd = shlex.split(shell_cmd)
        p = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            cwd=cwd,
            env=env)
        while True:
            line = p.stdout.readline()
            if not line and p.poll() is not None:
                break

            self.log_data(line)

        p.communicate()[0]
        status = p.returncode

        self.log_data("'%s' exited with local status: %d\n" % (cmd, status))
        if status != 0:
            raise Exception(
                "'%s' exited with local status: %d" % (cmd, status))

    def run_locally(self, shell_cmd):
        if isinstance(shell_cmd, dict):
            env = shell_cmd.get("env", {})
            cwd = shell_cmd.get("chdir", None)
            self._run_cmd_locally(shell_cmd["cmd"], cwd, env)
        else:
            self._run_cmd_locally(shell_cmd)

    def run_on_deployer(self, cmd):
        transport = self.client.get_transport()
        transport.set_keepalive(1)

        channel = transport.open_session()
        channel.get_pty()
        channel.setblocking(0)
        channel.exec_command(cmd)

        while True:
            rl, wl, xl = select.select([channel], [], [])
            if len(rl) > 0:
                data = channel.recv(1024)
                if not data:
                    break
                self.log_data(data)

        status = channel.recv_exit_status()
        self.log_data("'%s' exited with status: %d" % (cmd, status))
        channel.close()
        if status != 0:
            raise Exception("'%s' exited with status %d" % (cmd, status))

    def run_executable_on_deployer(self, executable, cwd=None):
        cwd = cwd or self.get_scratchdir()

        cmd = "env PATH=%s:$PATH bash -c \"cd %s ; %s\"" % (
            self.get_testdir(), pipes.quote(cwd), executable)
        self.log_data("Running '%s'\n" % (cmd))
        self.run_on_deployer(cmd)

    def run_playbook(self, playbook):
        self.run_on_deployer(
            "cd %s ; ansible-playbook -i %s/hosts/verb_hosts %s/%s" % (
                self.get_scratchdir(), self.get_scratchdir(),
                self.get_scratchdir(),
                playbook))

    # Run tempest tests

    def run_tempest_region(self, region, filters, tempest_cwd):
        ftp = self.client.open_sftp()
        fp = ftp.file(os.path.join(tempest_cwd, "tempest.filter"), "w")
        fp.write("\n".join(filters))
        fp.close()

        self.run_executable_on_deployer(
            "sudo -u tempest /opt/stack/tempest/bin/ardana-tempest.sh"
            " --config tempest_%s.conf"
            " --run-filter %s" % (
                region,
                pipes.quote(os.path.join(tempest_cwd, "tempest.filter"))
            ),
            cwd=tempest_cwd
        )

        for filename in ["tempest_%s.log" % region, "testrepository.subunit"]:
            fp = ftp.file(os.path.join(tempest_cwd, filename))
            with open("%s-%s" % (
                    self.log_filename, filename), "w") as local_fp:
                shutil.copyfileobj(fp, local_fp)
            fp.close()

        ftp.close()

    def run_tempest(self, tempest):
        tempest_cwd = os.path.join(
            "/tmp", "%s-%s" % (self.name, time.strftime('%Y%m%dT%H%M%SZ')))

        ftp = self.client.open_sftp()
        ftp.mkdir(tempest_cwd)
        remote_cwd = ftp.open(tempest_cwd)
        remote_cwd.chmod(0o777)
        remote_cwd.close()
        ftp.close()

        if isinstance(tempest, dict):
            for region, filters in tempest.items():
                self.run_tempest_region(region, filters, tempest_cwd)
        else:
            self.run_tempest_region("region1", tempest, tempest_cwd)

    # VM Operations that run locally

    def run_virsh_command(self, cmd, vms):
        if type(vms) != list:
            vms = [vms]
        for vm in vms:
            vm_name = "project-vagrant_%s" % vm
            self.log_data(
                "VM operation: %s virsh instance: '%s'" % (
                    cmd, vm_name))
            status = os.system("virsh %s %s" % (cmd, vm_name))
            if status != 0:
                raise Exception("Failed to %s '%s'" % (cmd, vm))

        # sleep to allow virsh to do its thing.
        time.sleep(1)

    def run_virsh_reboot(self, vms):
        self.run_virsh_command("reboot", vms)
        self._wait_for_vms_to_start(vms)

    def run_virsh_shutdown(self, vms):
        self.run_virsh_command("shutdown", vms)

    def run_virsh_start(self, vms):
        if type(vms) != list:
            vms = [vms]

        for vm in vms:
            vm_name = "minimal-vagrant_%s" % vm
            # Sytem is not running then we start it.
            status = os.system(
                'virsh list --all | grep -qE "%s[ ]+running"' % vm_name)
            if status != 0:
                self.run_virsh_command("start", vm)
            else:
                self.log_data("VM operation: %s is already running\n" % vm)

        self._wait_for_vms_to_start(vms)

    def _wait_for_vms_to_start(self, vms, max_retry=60):
        sleep_time = 3
        if type(vms) != list:
            vms = [vms]

        for vm in vms:
            self.log_data(
                "VM operation: waiting for %s to come back...\n" % vm)
            for i in range(0, max_retry):
                try:
                    client = self.connect(vm)
                except (paramiko.BadHostKeyException,
                        paramiko.AuthenticationException,
                        paramiko.SSHException,
                        paramiko.ssh_exception.NoValidConnectionsError,
                        socket.error):
                    if i >= max_retry - 1:
                        self.log_data(
                            "VM operation: Timed out waiting for %s\n" % vm)
                        raise

                    time.sleep(sleep_time)
                else:
                    self.log_data(
                        "VM operation: %s available after: %d\n" %
                        (vm, i * sleep_time))
                    # If we update the deployer_node then we should also use
                    # the new client object.
                    if vm == self.deployer_node:
                        self.client = client
                    break
            else:
                raise Exception("Failed to connect to %s after reboot" % vm)

    def load(self, filename):
        self.filename = filename
        self.testdata = yaml.load(open(filename))


def main(ssh_config, deployer_node, filename):
    actions = TestPlanAction(ssh_config, deployer_node)

    count = 0
    actions.load(filename)
    for testdata in actions.testdata:
        count += 1

        name = testdata["name"]

        if testdata.get("logfile", None):
            logfilename = testdata["logfile"]
        else:
            logfilename = "testsuite-%s.log" % name.replace(" ", "_")

        actions.set_loginfo(
            name, logfilename, testdata.get("prefix", "part%d" % count))

        actions.log_data("Start running *** %s ***\n\n" % name)

        vms = testdata.get("vms", [])
        if vms:
            actions.log_data("VM operations\n")
            for vm in vms:
                reboot_vms = vm.get("reboot", [])
                actions.run_virsh_reboot(reboot_vms)

                shutdown_vms = vm.get("shutdown", [])
                actions.run_virsh_shutdown(shutdown_vms)

                start_vms = vm.get("start", [])
                actions.run_virsh_start(start_vms)

        playbooks = testdata.get("playbooks", [])
        actions.log_data("Run playbooks: %s\n" % (",".join(playbooks)))
        for playbook in playbooks:
            actions.run_playbook(playbook)

        execs = testdata.get("exec", [])
        actions.log_data("Run executables: %s\n" % (",".join(execs)))
        for cmd in execs:
            actions.run_executable_on_deployer(cmd)

        tests = testdata.get("tests", [])
        actions.log_data("Run tests: %s\n" % (",".join(tests)))
        for testcmd in tests:
            actions.run_executable_on_deployer(testcmd)

        localexecs = testdata.get("local", [])
        actions.log_data("Run local commands\n")
        for testcmd in localexecs:
            actions.run_locally(testcmd)

        tempests = testdata.get("tempest", None)
        actions.log_data("Running tempest tests")
        if tempests:
            actions.run_tempest(tempests)

    sys.stdout.write("\n")
    if actions.log:
        actions.log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="XX")
    parser.add_argument("--ssh-config", type=str, action="store",
                        help="SSH configuration")
    parser.add_argument("--deployer-node", type=str, action="store",
                        help="",
                        default="server1")
    parser.add_argument("test_plan", nargs="+",
                        help="")

    args = parser.parse_args()
    for test_plan in args.test_plan:
        main(args.ssh_config, args.deployer_node, test_plan)
