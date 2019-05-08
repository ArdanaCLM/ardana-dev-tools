
(c) Copyright 2015 Hewlett Packard Enterprise Development LP
(c) Copyright 2017 SUSE LLC

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.


# CI jobs

This document lists the CI jobs associated with Ardana and how to run the scripts
behind them manually on your own workstation. It's a work in progress, so not
all jobs are described here yet, but will be.

The intent of this documentation is to allow you to reproduce and debug
locally any issues that are being flagged by CI. In addition you can use the
same methods to test before you submit code in the first place to gain a
degree of confidence that it should pass CI first time.

## ardana-ansible-syntax

This is a voting job that runs a set of syntax checkers against all yml files
found in all git repos used by ardana-dev-tools. Current checks are:

1. Invalid YAML syntax
2. Duplicate ansible playbooks
3. Duplicate ansible roles
4. Warnings/errors from the ansible-lint tool.

The exit code of #4 is currently being ignored because:
* We have existing code in our repos with genuine issues.
* The ansible-lint tool has some bugs that lead to spurious warnings.

The job scripts and playbooks assume the standard layout for ardana-dev-tools
work. In other words any repos that you are working on locally need to be
cloned in the same directory as ardana-dev-tools. Any that are not found there
will be pulled from git.

### Interactive running

You can run the full job interactively as follows:

    cd ardana-dev-tools
    bin/run-lint.bash

It does all of its work in temporary directories in the "scratch" subdir and
will not change anything in your sandbox, so should be safe to run at any time.
Note that by default it will always pull the latest code from git for all
repos *except the ones that you have checked out locally at the same level
as ardana-dev-tools*.

If you don't care about having the most up-to-date version of other people's
code then you can run the playbook directly with the "-e dev_env_global_git_update=false"
flag on the command line. This is much faster because reuses the code that is
already in "scratch" from the last run, but of course has the downside that you
are not comparing against the latest version of other people's code.

    cd ardana-dev-tools/ansible
    ansible-playbook -i hosts/localhost -e dev_env_global_git_update=false lint-run.yml

### YAML syntax

The yaml syntax checking script can also be run on its own to check the syntax
of any arbitrary file(s) on the filesystem. You can give it file or directory
names and if the latter it will recurse through all yml files in that tree.

e.g. check a file that is definitely not yaml:

    $ ardana-dev-tools/ansible/roles/lint/bin/parse-yaml.py /etc/hosts
    ERROR: yaml syntax error:
    while scanning for the next token
    found character '\t' that cannot start any token
    in "/etc/hosts", line 1, column 10
    $

