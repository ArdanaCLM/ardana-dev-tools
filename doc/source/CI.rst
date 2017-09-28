Continuous Integration
======================

----------------
Integration jobs
----------------

We have a basic integration job. This jobs bring up the associated cloud
in *ardana-input-model/2.0/ardana-ci* and are deployed via the ``astack.sh``
script. They are:

- ardana-standard-vagrant-integration-test
- ardana-mid-size-vagrant-integration-test
- ardana-mid-size-vagrant-rhel-integration-test
- ardana-standard-vagrant-upgrade-test


These jobs can run all services defined in the input model for the cloud.
But doing so make the jobs take a long time to run. To alleviate this we
restrict running certain services in the jobs to when we are changing certain
repositories only.


-----------------
Project stack job
-----------------

The project-stack job is run against all the ansible repositories. This deploys
a cloud specific by the service teams by calling ``astack.sh`` with the argument
*--project-stack* and passes in the project been tested.

Deploy
------

See :ref:`project-stack-deploy-label` section.


Testing
-------

After deploying the cloud to the service teams specifications the project-stack
job will execute a custom test plan from that team. To execute this plan against
the ardana/glance-ansible repository for example, a developer can run the following:

.. code-block:: bash

    $ ./test-project-stack.sh ardana/glance-ansible

This works is as follows. The structure of the ardana-ci/tests directory looks like the
following:

::

  glance-ansible/ardana-ci/
  |-- project/
  |   |-- data/
  |   |   |-- control_plane.yml
  |-- tests/
  |   |-- test-plan.yaml
  |   |-- any scripts needed by test-plan.yaml

``test-project-stack.sh`` will copy the *ardana-ci/tests* directory onto the
deployer into the ``~/ardana-ci-tests`` directory. This contains all the necessary
scripts and playbooks needed to run the test plan. Next we will execute a python
script on the host machine and this will parse the test plan specified in
``test-plan.yaml`` and execute all the parts specified in there.

The ``test-plan.yaml`` is a yaml file that contains a specification of how to
test the cloud and is made up of a list of individual parts. For example the
current glance-ansible test-plan.yaml looks like:

::

    - name: Test reconfigure
      logfile: testsuite-reconfigure.log
      prefix: reconfigure
      playbooks:
        - glance-reconfigure.yml

    - name: Validate glance
      exec:
        - validate-glance.bash

    - name: Test reboot
      logfile: reboot.log
      prefix: reboot
      vms:
        - reboot: server6
      exec:
        - ansible-playbook -i hosts/verb_hosts glance-start.yml
        - validate-glance.bash

    - name: Run tempest
      tempest:
        - "+tempest.api.image"
        # Image sharing is disabled by policy for security reasons; therefore these tests will not pass.
        - "-tempest.api.image.v2.test_images_member.ImagesMemberTest"
        - "-tempest.api.image.v2.test_images_member_negative.ImagesMemberNegativeTest"
        - "-tempest.api.image.v1.test_image_members.ImageMembersTest"
        - "-tempest.api.image.v1.test_image_members_negative.ImageMembersNegativeTest"
        - "-tempest.api.image.v1.test_images.CreateRegisterImagesTest"
        # The v1 listing tests rely on creating test images using the "set location" feature. This
        # is disabled by policy for security reasons; therefore these tests will not pass.
        - "-tempest.api.image.v1.test_images.ListImagesTest"

For each part of the test plan you can specify the following configuration:

+-----------+----------+------------------------------------------------------+
| Option    | Required | Description                                          |
+===========+==========+======================================================+
| name      | Yes      | Name of the test                                     |
+-----------+----------+------------------------------------------------------+
| logfile   | No       | Name of a log file to use for this test              |
+-----------+----------+------------------------------------------------------+
| prefix    | No       | Prefix the output from the test when printing        |
|           |          | to console.                                          |
+-----------+----------+------------------------------------------------------+
| vms       | No       | List of VM operation to perform. This can include    |
|           |          | ``reboot`` to reboot a list of named VM's,           |
|           |          | ``shutdown`` to stop a list of VM's, and ``start``   |
|           |          | to start a list of VM's. The name of the VM's is the |
|           |          | same names reported by vagrant status.               |
+-----------+----------+------------------------------------------------------+
| playbooks | No       | List of playbooks to run against cloud. These are in |
|           |          | the ~/scratch/ansible/next/ardana/ansible directory  |
|           |          | and against the ansible inventory hosts/verb_hosts   |
|           |          | which was generated by the config processor.         |
+-----------+----------+------------------------------------------------------+
| exec      | No       | List of scripts to run on the deployer.              |
+-----------+----------+------------------------------------------------------+
| local     | No       | Run a command locally on the host machine. Can be a  |
|           |          | dictionary that contains the `cmd` key of what to    |
|           |          | run locally and the following optional keys:         |
|           |          | - env                                                |
|           |          | - chdir                                              |
|           |          | - cwd                                                |
|           |          | The command is run within with the `ardana-ci/tests` |
|           |          | directory and the PATH environment variable is set   |
|           |          | to default + this directory.                         |
+-----------+----------+------------------------------------------------------+
| tempest   | No       | List of regular expressions to match which           |
|           |          | tempest tests to run. Tests starting with ``+`` are  |
|           |          | whitelisted, whereas tests starting with ``-`` are   |
|           |          | blacklisted. If whitelist is empty, all available    |
|           |          | tests are fed to blacklist. If blacklist is empty,   |
|           |          | all tests from whitelist are returned.               |
+-----------+----------+------------------------------------------------------+

When we execute each part of the test plan, we run all the specified ``vms``
operations first, followed by all the ``playbooks``, the all the executable
specified by ``exec``, and finally the tempest tests. If you want break up
this order then you can break up the test plan into different parts.

Tempest notes
~~~~~~~~~~~~~

Note that when you want to run any of the tempest tests. You need to include the
``tempest`` service on one of the nodes in your cloud. Then you can specify a
list of regular expresissions as discussed above like so:

::

    - name: Run tempest
      tempest:
        - "+tempest.api.identity.v2"

You can also configure tempest to run against different regions. The default region
is ``region1`` but if we have configure a multi-region cloud in
:ref:`project-stack-deploy-label` section we can run tempest a second time against
a different region like so:

::

    - name: Run tempest against region1
      tempest:
        region1:
          - "+tempest.api.image"
          # Image sharing is disabled by policy for security reasons; therefore these tests will not pass.
          - "-tempest.api.image.v2.test_images_member.ImagesMemberTest"
          - "-tempest.api.image.v2.test_images_member_negative.ImagesMemberNegativeTest"
          - "-tempest.api.image.v1.test_image_members.ImageMembersTest"
          - "-tempest.api.image.v1.test_image_members_negative.ImageMembersNegativeTest"
          - "-tempest.api.image.v1.test_images.CreateRegisterImagesTest"
          # The v1 listing tests rely on creating test images using the "set location" feature. This
          # is disabled by policy for security reasons; therefore these tests will not pass.
          - "-tempest.api.image.v1.test_images.ListImagesTest"
        region2:
          - "+tempest.api.image"
          # Image sharing is disabled by policy for security reasons; therefore these tests will not pass.
          - "-tempest.api.image.v2.test_images_member.ImagesMemberTest"
          - "-tempest.api.image.v2.test_images_member_negative.ImagesMemberNegativeTest"
          - "-tempest.api.image.v1.test_image_members.ImageMembersTest"
          - "-tempest.api.image.v1.test_image_members_negative.ImageMembersNegativeTest"
          - "-tempest.api.image.v1.test_images.CreateRegisterImagesTest"
          # The v1 listing tests rely on creating test images using the "set location" feature. This
          # is disabled by policy for security reasons; therefore these tests will not pass.
          - "-tempest.api.image.v1.test_images.ListImagesTest"
