=================================
Ardana Cloud Lifecycle Management
=================================

==================
Developer workflow
==================

This a HOW-TO for developers who wish to run Ardana. It is going to
document use cases that developers may need to execute as well as
various tips and tricks that currently only the authors of the code
in question understand.

---------
astack.sh
---------

Basics
------

.. code-block:: bash

    $ ./astack.sh

And wait.

This will checkout all the repositories that we need, download any
artifacts that we need, build all venv packages that we need using
vagrant managed build VMs, and then it will use vagrant to bring a
number of virtual machines on which we will deploy the Ardana cloud.

Clouds
------

We can pass a cloud argument to ``astack.sh``. This defaults to
deployerincloud and the definition for this cloud is defined in
ardana-input-model. The directory *ardana-input-model/2.0/ardana-ci*
defines others clouds which differ in their topology and which we
can use by passing their name as a positional argument to ``astack.sh``.

1. standard
2. mid-size
3. deployerincloud
4. multi-cp

To bring up standard cloud we run

.. code-block:: bash

    $ ./astack.sh standard


.. _project-stack-deploy-label:

Project specific stacks
-----------------------

We can bring we project specific stacks. Service teams can define
multiple stacks in their ansible repositories. To use them a developer just
runs the following in the case of glance:

.. code-block:: bash

    $ ./astack.sh --project-stack ardana/glance-ansible tiny

This will bring up a cloud based in the vagrant directory
*ardana-dev-tools/ardana-vagrant-models/project-vagrant* based on the input model
found in *glance-ansible/ardana-ci/tiny/*. When --project-stack is specified, the
cloud we bring up uses the input model *ardana-input-model/2.0/ardana-ci/project* as
a basis for all clouds now. Service teams can then specify in a special directory
a bunch of files that ``astack.sh`` will overlay on top of the base project
input model. This will now be the input model for the cloud tiny.

The directory structure of glance-ansible looks like this:

::

  glance-ansible/ardana-ci/
  |-- project/
  |-- astack-options
  |   |-- data/
  |   |   |-- control_plane.yml
  |-- tiny/
  |   |-- data/
  |   |   |-- control_plane.yml
  |   |   |-- servers.yml


So once the ``--project-stack`` argument is passed in the concept of the cloud
argument to ``astack.sh`` changes. This breaks away from the default behaviours
which is to specify a directory in *ardana-input-model/2.0/ardana-ci* which is the input
model to use. Now the cloud argument is a specify a directory in the ansible
repository from which to overlay the base project input model. As can be seen
service teams can define any number of clouds like so.

The `astack-options` file can be used to optionally pass in default values to the
project-stack cloud.

RHEL support
------------

We can bring up a cloud with all the compute nodes deployed on RHEL.

.. code-block:: bash

    $ ./astack.sh --rhel-compute


Tips
----

Local sites
~~~~~~~~~~~

We have mirrored some large common artifacts needed for the build like ISO's, etc.

.. code-block:: bash

    $ export ARDANA_SITE=provo

No setup and no build
~~~~~~~~~~~~~~~~~~~~~

For example. After a successful deployment you can speed up your workflow
by running

.. code-block:: bash

    $ ./astack.sh --no-setup --no-build

As your system will be setup and venv packages already built, we can save
time and reuse what you have already downloaded. Note that you can / will
run into problems every now and then because the one or more venv packages
are out of date and require to be rebuilt. It can be hard to know when this
is the case, but if you use this you should still rebuild all the venv
packages regularly.

Git performance
~~~~~~~~~~~~~~~

For normal operations we can turn off checking and updating the local git
caches.

.. code-block:: bash

    $ export ARDANA_GIT_UPDATE=no

When you now build the venv packages or provision the deployer node, you will
not update and local git caches and you just use the current state of these
repositories. This is a lot faster then going over the network to check if
anything if updated.

When you are then ready, and feeling lucky you can update all the
repositories without changing your environment by running the following
command:

.. code-block:: bash

    $ ./bin/astack.sh --update-only

Then you can bring up a fresh cloud running with the lastest code by
re-running the ``astack.sh`` script.

Note that if you follow this, then it would be a good idea to rebuild all
you venv packages after updating all your repositories. This avoids the issue
of having to track down breakage because of incompatibilities between the
different repositories.

Updating ansible repositories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After deploying and maybe confirming your problem. You develop a fix in
one of the ansible repositories. We can run the ``update-ansible.sh`` script
inside the vagrant directory. For example if you are running the mid-size
cloud and you want to fix and deploy keystone again then you can run
the following comment:

.. code-block:: bash

    $ cd ardana-dev-tools/ardana-vagrant-models/mid-size-vagrant
    $ ../../bin/update-ansible.sh keystone-ansible

This will copy your local copy of keystone-ansible to the correct
place, and re-run configuration processor and ready the deployer for
deployment. You can also optionally run a playbook after this.

.. code-block:: bash

    $ ../../bin/update-ansible.sh keystone-ansible keystone-deploy.yml

Which will execute the keystone-deploy.yml after re-running the configuration
processor and readying the deployer.

You can skip the re-running the configuration processor and go straight to
readying the deployer by passing the ``--no-config`` argument to
``update-ansible.sh``.

Building individual venv packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you are working on a service and just wish to rebuild a single package
then you can run the following command.

.. code-block:: bash

    $ ./bin/build-venv.sh cinder nova

You can also speed this up by not trying to download latest ISO artifacts,
and not to try and checkout the packages.

.. code-block:: bash

    $ ./bin/build-venv.sh --no-artifacts --no-checkout nova

We no packages specified `build-venv.sh` will build every package.

Updating / upgrading individual venv packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

    $ cd ardana-dev-tools/ardana-vagrant-models/mid-size-vagrant
    $ ../../bin/update-venv.sh --no-artifacts --no-checkout nova nova-upgrade.yml


------------
Other topics
------------

.. toctree::
   :maxdepth: 1

   CI
