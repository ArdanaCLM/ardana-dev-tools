Developer Environment Ansible
=============================

The developer environment is driven through Ansible tasks, arranged in roles.  These
roles are driven by top-level playbooks that are named according to the function that
they perform.

Developers are expected to execute the top-level playbooks as necessary to accomplish
build tasks.  For example, to validate that the current environment is capable of building
and testing Ardana OpenStack, the following would be run:

```
ansible-playbook -i hosts/localhost dev-env-validate.yml
```

The playbooks should be self-documenting in what they do, and so are not listed here.

## Roles

### apt-consumer

### ccache

### dev-env

Tasks related to the creation and upkeep of a developer environment.

### image-build

### pip-consumer

### ssh-bootstrap

### vagrant

Tasks related to the operation of the vagrant environment, and used by vagrant in
the provisioning of machines.

### venv

