
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


# The service deploy playbook

The purpose of a &lt;service&gt;-deploy playbook (e.g. nova-deploy.yml) is to
orchestrate the deployment of the set of service components (e.g. nova-api,
nova-scheduler, etc.) of a service (e.g. nova ) across a set of nodes, such
that the service is fully operational (across the set of nodes selected). The
orchestration is achieved by executing the per-service verb playbooks, as
outlined for the Ardana playbook model. In addition to the standard verb
playbooks, the &lt;service&gt;-deploy playbook may also invoke custom service
playbooks (which may or may not be directly tied to a specific service
component).

## &lt;service&gt;-deploy playbook structure

The &lt;service&gt;-deploy playbook will contain one or more plays, where each play:

- Specifies a set of target hosts
- Specifies a set of roles to be applied to these target hosts
- Executes a number of tasks

Appropriate hosts for the play are specified by reducing the set specified by the
'target\_hosts' variable, generally using the hostgroups provided by Configuration
Processor (CP). For example, to run the play only on Nova API nodes:

        "{{ target_hosts | default('all') }}:&NOV-API"

Similar hostgroups are provided for each service component. CP also offers service
hostgroups, named e.g. NOV-NOV. However the names of these are expected to change.
The Ansible documentation offers full details on host specifiers:
http://docs.ansible.com/intro\_patterns.html

Roles serve two purposes in Ardana: providing variables (from defaults/main.yml) and
grouping tasks. If a main task (tasks/main.yml) is supplied, this will be executed
every time the role is included. Generally this hampers reuse and is not recommended.
On occasion it may be necessary to use one to set facts (variables) required by the
role's tasks.

The tasks are what cause the play to actually have an effect. To provide some
consistency across services, Ardana specifies a number of 'verbs' (i.e. task names):

    * Start
    * Stop
    * Install
    * Configure

These have been chosen for ease of composition into higher-level playbooks and should
be used when suitable. Additional tasks may be called if required.

### Typical layout of a deploy playbook

The layout of a deploy playbook for a typical Openstack service is as follows:

1. A set of plays per service-component (e.g. nova-api) that installs and configures
it (without starting it), e.g.:

        - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
          sudo: yes
          roles:
          - NOV-API
          tasks:
          - include: roles/NOV-API/tasks/install.yml
          - include  roles/NOV-API/tasks/stop.yml
          - include: roles/NOV-API/tasks/configure.yml

    This play executes a set of verbs from a standard service-component role. The
NOV-API role inclusion is used to set up any common variables required across the
verb playbooks.

2. One or more plays based on the &lt;service&gt;-post-configure role, which
run on only one node in the cluster of nodes for that core service. This play
runs a set of tasks that are required before the service components are
started, examples for a typical Openstack service being:

    - Database creation and setup
    - Keystone endpoint setup
    - Rabbitmq user + other resources setup (not yet supported).

    Not all services will require the above set of tasks and will invariably
require additional service-specific tasks to be run the before set of services
can be started. An example post-configure play is as follows:

            - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
              sudo: yes
              roles:
              - nova-post-configure
              # All these tasks should be set to run-once
              tasks:
              - include: roles/nova-post-configure/tasks/db-setup.yml
              - include: roles/nova-post-configure/tasks/mq-setup.yml
              #... additional service-specific run-once tasks here that are required
              # before starting services.

    It is best practice to code these tasks into separate re-usable task files
(rather than, for example, grouping keystone endpoint setup and db setup into
a single task file). The Ardana convention is to group these tasks into a single
role named &lt;service&gt;-post-configure. Ensure that each of the tasks are
run with the run-once Ansible directive to ensure that they are only executed
once within a single Ansible playbook run. For example, a sample task from the
db-setup verb:

        - name: nova-post-configure | _db_configure | Run nova-manage db sync
          command: >
            {{ 'nova-api' | bin_dir }}/nova-manage
            --config-file {{ 'nova-api' | config_dir }}/nova/nova.conf
            db sync
          run_once: true

    **Invoking OpenStack clients**

    As listed above, keystone endpoint setup is another typical task that is run
as part of the post-configure phase. This task is notable because it involves
usage of an OpenStack client, the keystone client in this case. As with
service-components, the CP generates a hostgroup per OpenStack client, which
are used in plays to target hosts containing the required OpenStack client,
e.g. KEY-CLI for the keystone client, NOV-CLI for the nova client and so on.
The default install location for OpenStack clients is on the Ardana deployer
node. An example nova-post-configure play that targets a node with the
keystone client is as follows:

        - hosts: "{{ target_hosts | default('all') }}:&KEY-CLI"
          sudo: yes
          roles:
            - nova-post-configure
          # This task should be set to run-once
          tasks:
            - include: roles/nova-post-configure/tasks/keystone_conf.yml
              ansible_python_interpreter: "{{ KEY_CLI.vars.keystone_client_python_interpreter }}"

    As each OpenStack client is installed in a python virtual environment, the
"ansible\_python\_interpreter" may need to be specified, depending on the
implementation of the OpenStack client Ansible module. If the Ansible module
uses the OpenStack client python library, the python interpreter needs to be
specified by referencing an Ansible variable output by the CP, as shown in the
example above. On the other hand, if the Ansible module uses the command-line
client, the python interpreter does not need to be specified.

3. The service-deploy playbook finishes by invoking the service-start playbook
to start each service component, e.g.:

        # The following playbook is used to start all nova services and can also
        # be used standalone.
        - include: nova-start.yml

A sample Nova deploy playbook is as follows:

    - hosts: "{{ target_hosts | default('all') }}:&NOV-CND"
      sudo: yes
      roles:
      - NOV-CND
      tasks:
      - include: roles/NOV-CND/tasks/install.yml
      - include: roles/NOV-CND/tasks/stop.yml
      - include: roles/NOV-CND/tasks/configure.yml

    - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
      sudo: yes
      roles:
      - NOV-API
      tasks:
      - include: roles/NOV-API/tasks/install.yml
      - include  roles/NOV-API/tasks/stop.yml
      - include: roles/NOV-API/tasks/configure.yml

    # ... the above plays are repeated to bring each service component into
    # a configured and stopped state.

    # TODO this will be something like &NOV-ALL when supported by CP.
    - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
      sudo: yes
      roles:
      - nova-post-configure
      # All these tasks should be set to run-once
      tasks:
      - include: roles/nova-post-configure/tasks/keystone-endpoint-setup.yml
      - include: roles/nova-post-configure/tasks/db-setup.yml
      - include: roles/nova-post-configure/tasks/mq-setup.yml
      #... additional service-specific run-once tasks here that are required
      # before starting services.

    # The following playbook is used to start all nova services and can also
    # be used standalone.
    - include: nova-start.yml

### Deploy playbook layout using private playbooks

The above sample Nova deploy playbook begins with a repeated pattern of
install, stop and configure for each service component. An alternative is to
group the calls for a single verb across all service components into separate
operation playbooks, e.g. \_nova-configure.yml:

    ---
    - hosts: "{{ target_hosts | default('all') }}:&NOV-CND"
      sudo: yes
      roles:
      - NOV-CND
      tasks:
      - include: roles/NOV-CND/tasks/configure.yml

    - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
      sudo: yes
      roles:
      - NOV-API
      tasks:
      - include: roles/NOV-API/tasks/configure.yml

    - hosts: "{{ target_hosts | default('all') }}:&NOV-SCH"
      sudo: yes
      roles:
      - NOV-SCH
      tasks:
      - include: roles/NOV-SCH/tasks/configure.yml

    # ... repeated for each service component

A similar \_nova-install.yml could be defined, along with a nova-stop.yml
and nova-start.yml, which would be created in any case as part of the standard
operation playbook API (see [Ardana Ansible Guide](../ardana-ansible-guide.md)). This
leads to a simplified nova deploy playbook:

    ---
    - include: _nova-install.yml
    - include: nova-stop.yml
    - include: _nova-configure.yml

    - hosts: "{{ target_hosts | default('all') }}:&NOV-API"
      sudo: yes
      roles:
      - nova-post-configure

      # All these tasks should be set to run-once tasks:
      - include: roles/nova-post-configure/tasks/db_create.yml
      - include: roles/nova-post-configure/tasks/db_configure.yml
      - include: roles/nova-post-configure/tasks/keystone_conf.yml

    - include: nova-start.yml

\_nova-install.yml and \_nova-configure.yml are defined as private operation
playbooks, as they are not intended to be invoked directly by a user, as part
of the standard API for managing the lifecycle of the nova services. The
benefit of these private playbooks is that they may be re-used in other
high-level operation playbooks, e.g. \_nova-configure.yml may be re-usable in
the nova-upgrade.yml or nova-reconfigure.yml playbooks. A sample of the
Ardana Ansible hierarchy, including the layout of these operation playbooks is
provided at the end of the main [Ardana Ansible Guide](../ardana-ansible-guide.md).

This template demonstrates a common structure that should be applicable to most
services being deployed within Ardana. Following this structure will provide consistency
between services and maximise reusability. However, services are expected to use
their best judgment and deviate where necessary. For example, beyond the standard
verb tasks, Swift needs to build rings - this play could be coded as:

    - hosts: "{{ target_hosts | default('all') }}:&SWIFT-PRXY[0]"
      sudo: yes
      roles:
      - SWF-RNG
      tasks:
      - include: roles/SWF-RNG/tasks/ring-build.yml
      - include: roles/SWF-RNG/tasks/ring-distribute.yml

## Post-deployment tasks

The service deploy playbook should bring a service to an operational state. However,
for some services to be practically useful to a non-admin user, additional
configuration must be performed. For example, setting up Nova flavors, Cinder volume
types and loading Glance images. These tasks should be executed by a
&lt;service&gt;-cloud-configure playbook. See [Cloud Configure
Guide](service-cloud-configure.yml.md) for guidance on writing this.
