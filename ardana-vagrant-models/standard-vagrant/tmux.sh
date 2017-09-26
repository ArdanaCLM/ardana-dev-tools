#!/bin/bash
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
tmux new -d -s vagrant -n 'deployer' 'vagrant ssh deployer'
tmux neww -n 'ctl1' 'vagrant ssh ccn-0001'
tmux neww -n 'ctl2' 'vagrant ssh ccn-0002'
tmux neww -n 'ctl3' 'vagrant ssh ccn-0003'
tmux neww -n 'compute1' 'vagrant ssh COMPUTE-0001'
tmux neww -n 'compute2' 'vagrant ssh COMPUTE-0002'
tmux neww -n 'compute3' 'vagrant ssh COMPUTE-0003'
tmux select-window -t :0
tmux attach -d -t vagrant
exit 0
