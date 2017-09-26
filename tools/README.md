External tools
==============

This is where external tools that are required by the
build process are installed.

To setup the image build area you should execute the following from `ardana-dev-tools/ansible`:

```
ansible-playbook -i hosts/localhost setup-image-build.yml
```

Optionally you can pass the `dev_env_image_tools_dir` variable on the command line to target
a specific location for the operations to occur:

```
ansible-playbook -i hosts/localhost setup-image-build.yml \
    -e dev_env_image_tools_dir=~/ardana/ardana-dev-tools
```

