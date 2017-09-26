This is a temporary copy of stock diskimage-builder element
"pip-and-virtualenv" required for Octavia amphora image.

It has been modified from upstream to force package installs.
Leaving the source-repository-pip-and-virtualenv in and overriding
the DIB_INSTALLTYPE causes reviewer questions.

This element has also been modified to enforce the Ardana pypi mirror.
Unfortunately the upstream pypi package does not support trusted hosts
which is sadly needed in the Ardana environment.

Define these environment variables to setup the mirror.
DIB_PYPI_MIRROR_URL
DIB_PYPI_TRUSTED_HOST

Currently that is done in:
ansible/roles/image-build/defaults/main.yml - image_build_dib_env

This should come directly from diskimage-builder package in the future.
