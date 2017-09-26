#!/usr/bin/python
# -*- coding: utf-8 -*-
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

from ansible.errors import AnsibleError
from ansible.runner.return_data import ReturnData
from ansible import utils


class ActionModule(object):
    '''Output warning with custom message'''

    TRANSFERS_FILES = False

    def __init__(self, runner):
        self.runner = runner

    def run(self, conn, tmp, module_name, module_args, inject,
            complex_args=None, **kwargs):
        args = {}
        if complex_args:
            args.update(complex_args)
        args.update(utils.parse_kv(module_args))
        if 'msg' not in args:
            raise AnsibleError("'msg' is a required argument.")

        msg = "WARNING: %s" % args['msg']
        utils.display(msg, 'bright red')

        result = dict(
            changed=True,
            msg=msg,
        )
        return ReturnData(conn=conn, result=result)
