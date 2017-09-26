Updating vagrant-libvirt gem
============================

    git clone http://git.suse.provo.cloud/.../vagrant-libvirt.git
    git checkout hp/master

Now patch vagrant libvirt with your change.

Next we want to bump the version of vagrant-libvirt so that we install
the correct version during the running of dev-env-install.yml. To do this
add a patch on vagrant-libvirt that bumps the version in
"lib/vagrant-libvirt/version.rb".

Build the new gem

    gem build vagrant-libvirt.gemspec

Now copy your gem to the files directory here and update "defaults/main.yml"
with the latest version.
