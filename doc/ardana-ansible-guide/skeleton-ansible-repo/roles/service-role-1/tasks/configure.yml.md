
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


# The configure verb playbook

This playbook contains tasks to carry out configuration of a particular
service component, a common task being to write out a configuration file, e.g.
keystone.conf for the keystone api service.

The general handling of service configuration files is under investigation
and will require changes in the configuration processor, tracked under BUG-179.
Another issue that will be dealt with in the future is the handling of
sensitve data, such as passwords. For now, this data should be stored plain
text, pending resolution of BUG-158.

For the current Ardana playbook model, the recommendation is to avoid using
handlers for triggering the automatic restart of services based on
configuration changes, but instead rely on explicit start/stop verbs at
the higher-level playbook (e.g. in &lt;service&gt;-deploy.yml). Note, however
that this model is under review and subject to change as we validate it
for the orchestration of multiple services.

### Example

See keystone-ansible/roles/KEY-API/tasks/configure.yml

The following example copies configuration files into /etc/keystone
from the keystone-ansible/roles/KEY-API/files directory on the
keystone-ansible repo:

```
- name: Create several Keystone config files
  copy: src={{ item }} dest=/etc/keystone/{{ item }} owner={{ keystone_user }} group={{ keystone_group }} mode=640
  with_items:
    - keystone-paste.ini
    - logging.conf
    - policy.json
```

The current mechanism for updating the contents of a configuration file is to use crudini:

```
- name: Update keystone.conf
  command: crudini --set /etc/keystone/keystone.conf {{ item }}
  with_items:
    - 'DEFAULT admin_token {{ KEY_API.vars.keystone_admin_token }}'
    - 'DEFAULT log_config_append /etc/keystone/logging.conf'
    - 'database connection  mysql://{{ KEY_API.consumes_FND_MDB.vars.mysql_admin_user }}:{{ KEY_API.consumes_FND_MDB.vars.mysql_admin_password }}@{{ KEY_API.consumes_FND_MDB.vips.public[0].host }}/keystone'
```

Note that the example contains references to variables that are output by
the configuration processor into the ansible staging dir on the deployer
node. The current mnemonic style is also planned to be changed to full
service component names, e.g. "keystone-api", see BUG-27
