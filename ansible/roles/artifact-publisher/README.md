This is used during a build to generate an artifacts file in ardana-dev-tools

The format of this file is <type> <branch> <version> <absolute filename> which can
later be processed by the hml-dev-tools/bin/archive.bash script to copy
files up to Gozer static server.

So if you generate a file called sles-20150403T091006Z.tgz say, which you
want to archive for reuse. Then you add next add the following task to your
playbook:

    - name: image-build | build-sles-qcow2 | Save artifact pointer
      include: ../../artifact-publisher/tasks/save-artifact.yml
      vars:
        type: "sles"
        branch: "{{ image_artifact_branch.stdout }}"
        version: "{{ image_version }}"
        filename: "{{ dev_env_working_dir }}/sles-{{ image_version }}.tgz"


Later if configured, jenkins will call ardana-dev-tools/bin/archive.bash which
will parse this file and correctly copy the files over to the static server.
