
(c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
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


Ansible Style Commandments
==========================

* Ansible YAML files must have the `.yml` file extension and not
  `.yaml`.
* Start of YAML files should contain a directive start indicated by a
  triple dash "---" or a comment followed by a triple dash.

    Incorrect:

        ---
        # File description
        my_yaml_beyond:
          - val1
          - val2

    Correct:

        # Start of new yml file which has the option of
        # being a multi-line comment also.
        ---
        my_yaml_beyond:
          - val1
          - val2

* Indents in Ansible YAML files must be 2 spaces wide.
* Break long lines using YAML line continuation. Attempt to keep all
  lines shorter than 80 characters wide.

  Incorrect:

      - file: dest="{{ test }}" src="./foo.txt" mode=0077 state=present user="root" group="wheel"

  Correct:

      - file:
          dest: "{{ test }}"
          src: "./foo.txt"
          mode: 0777
          state: present
          user: "root"
          group: "wheel"

* YAML arrays should always use the multi-line array syntax:

      my_array:
        - foo
        - bar
        - buzz

  Expressions Ansible will evaluate are exempt from this:

      with_items: ([ "id_rsa", "id_rsa.pub" ] | flatten(["a", "b"]))
      when: my_result is success

* Ansible arrays must contain the dash "-" on the same line as the
  array content:

    Incorrect:

        american:
          -
            Boston Red Sox
          -
            Detroit Tigers
          -
            New York Yankees

    Correct:

        american:
          - Boston Red Sox
          - Detroit Tigers
          - New York Yankees

* Ansible arrays must contain a single space between the dash and the array
  name.

    Incorrect:

        english:
          -Liverpool
          -  Everton

    Correct:

        english:
          - Liverpool
          - Everton

* All actions must have a name. The name string in a role must have
  the following format, "\$role | \$task | \$description". `$role`
  corresponds to the ansible role, e.g. NOV-API, `$task` corresponds
  to the task in the role, e.g. install or configure. `$description`
  must be an unambiguous and terse explanation of the action.

  Incorrect:

      - name: create directory
        file:
          path: "{{ nova_service_conf_dir }}/rootwrap.d"
          owner: "{{ nova_system_user }}"
          group: root
          mode: 0755
          state: directory

  Correct:

      - name: nova-common | configure | Create directory for rootwrap filters
        file:
          path: "{{ nova_service_conf_dir }}/rootwrap.d"
          owner: "{{ nova_system_user }}"
          group: root
          mode: 0755
          state: directory

* Variables from Config Processor should only be accessed in roles using
  variables aliased in "defaults/main.yml".

* Variable names must match one of the allowable patterns in a top level play
  or be all lowercase. Alternatively they can be derived from a function.
  Allowable patterns:

     - UPPER.consumes_UPPER.lowercase
       e.g. MON_API.consumes_KEY_API.vars.keystone_monasca_user
     - UPPER.vars.lowercase
       e.g. KEY_CLI.vars.keystone_client_python_interpreter
     - lowercase
       e.g. host.my_disk_models.volume_groups
     - A function to generate a variable
       e.g. "{{ lookup('file', './some/file/path') }}"

* Use spaces around jinja variable names. `{{ var }}` not `{{var}}`.
* Do not use spaces inside the square brackets. `foo['bar']` not `foo[ 'bar' ]`.
* Registered values must end in `_result` unless they start with 'ardana_notify_':

  Incorrect:

      - name: Check if dayzero already installed
        stat:
          path: "{{ 'dayzero' | venv_dir }}"
        register: dayzero_venv_dir

  Correct:

      - name: Check if dayzero already installed
        stat:
          path: "{{ 'dayzero' | venv_dir }}"
        register: dayzero_installed_result

      - name: _SWF_CMN | configure | Copy /etc/rsyslog.d/40-swift.conf
        template:
          src: 40-swift.conf.j2
          dest: /etc/rsyslog.d/40-swift.conf
          owner: root
          group: root
          mode: 0644
        register: ardana_notify_swift_common_rsyslog_restart_required

* When defining paths, do not include trailing slashes. `/foo/bar` not
  `/foo/bar/`. When concatenating paths, use the same convention
  `{{ my_path }}/bar` not `{{ my_path }}bar`.

* Join paths. To join path it is possible to use the custom filter `joinpath`. For example if
  you want to join the strings `etc` and `nova` you can use `{{ 'etc' | joinpath('nova') }}` the
  results will be `etc/nova`.

* Use the ``key: value`` syntax for action arguments when the action spans
  more than one line.

    Incorrect:

        - name: create directory
          file: >
            path="{{ nova_service_conf_dir }}/rootwrap.d"
            owner="{{ nova_system_user }}"
            group="root"
            mode="0755"
            state="directory"

    Correct:

        - name: nova-common | configure | Create directory for rootwrap filters
          file:
            path: "{{ nova_service_conf_dir }}/rootwrap.d"
            owner: "{{ nova_system_user }}"
            group: root
            mode: 0755
            state: directory

    Correct:

        - name: "NOV-CMP | install | Install the nova-compute service from the nova venv"
          install_package: name=nova service=nova-compute state=present

* Use Ansible modules where available.

    Incorrect:

          - command: sudo mkdir -p /var/log/neutron/hpvcn-agent

    Correct:

          - file:
              path: /var/log/neutron/hpvcn-agent
              state: directory
              mode: 0640
            become: yes

* Do not include blank lines at the end of the file.

* Vim directives should not be included - these are your preferences about how
  you view the file in vim. Not everyone uses vim and not everyone wants their
  settings overridden with yours.

* Mode must be specified for file, copy and template tasks. It may be symbolic
  (e.g. "u=rw,g=r,o=r"), a variable (e.g. "{{ mode }}") or octal
  (e.g. 0700, "0700"). Octal modes must be four digits, the first digit must be
  a zero.
  User permissions must be at least equal to group permissions.
  Group permissions must be at least equal to other permissions.
  Write and/or execute permissions require read permission.
  To set the sticky, setuid or setgid bits, provide an octal mode in a variable.

    Incorrect:

        - name: nova-common | configure | Create directory for rootwrap filters
          file:
            path: "{{ nova_service_conf_dir }}/rootwrap.d"
            owner: "{{ nova_system_user }}"
            group: root
            state: directory

    Incorrect:

        - name: nova-compute | configure | Apply template
          template:
          src: "compute-logging.conf.j2"
          dest: "{{ nova_service_conf_dir }}/compute-logging.conf"
          owner: root
          group: "{{ nova_system_group }}"
          mode: 640

    Correct:

        - name: nova-common | configure | Create directory for rootwrap filters
          file:
            path: "{{ nova_service_conf_dir }}/rootwrap.d"
            owner: "{{ nova_system_user }}"
            group: root
            mode: 0755
            state: directory
