Build-box vagrant environment
=============================

This is currently a cheap-as-chips vagrant environment that sets
up SLES or RHEL buildboxes.

The venv-packaging (and potentially other stuff requiring a
scratch environment) uses this as a staging machine for builds.

After a "vagrant up", you can build packaged venvs as follows:

As a pre-requisite: check out the nova, keystone, etc. sources in
directories parallel to ardana-dev-tools:

```
pushd ../..
git clone http://git.ci.prv.suse.net/openstack/keystone
git clone http://git.ci.prv.suse.net/openstack/nova
# ... etc ...
popd
```

To build the basic packages, the following will work:

```
ansible-playbook -i ../ansible/hosts/vagrant.py ../ansible/venv-build.yml
```

This should produce both tarballs and manifest files in the
`../scratch` directory. One of those, `packager-1.tgz` is required by the
various other vagrant environments: single, standard, and knight.

With those packages built, the deployment process can be continued.


Rebuilding packaged virtual environments
========================================

A single, small change to the nova source (for instance) can be repackaged
without going through the entire process of destroying and rebuilding its
virtual environment:

```
vi ../../nova/nova/blah.py
ansible-playbook -i ../ansible/hosts/vagrant.py ../ansible/venv-build.yml -e rebuild=True
```

So the output venv may not be equivalent to a pristine full build under some
circumstances. Caveat emptor, but reasoning about what dependencies, etc, may
be orphaned in a pre-existing venv is relatively straightforward.


Rebuilding a subset of virtual environments
===========================================

The build process can be further targeted by giving a list of venvs to rebuild.

```
ansible-playbook -i ../ansible/hosts/vagrant.py ../ansible/venv-build.yml \
       -e rebuild=True -e '{"packages": ["nova"]}'
```

NOTE: With ansible v1, the support for this mechanism requires an explicit listing
of all possible packages in `ansible/venv-build.yml` and a corresponding list in
`ansible/roles/venv/defaults/main.yml` - if you're adding another service, you'll
need to supply changes to both of those at present.


When is this VM required to be running?
=======================================

If you have no other mechanism for producing tarballs in the scratch directory,
you can bring up this VM to run the above commands.

Once those tarballs are in place, this VM can be shut down safely: the developer
pipeline rendezvous with the build process through the scratch directory. However,
you may wish to keep the build VM up and running, especially if you're iterating
on changes to a service.
