#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# Utility function for re-use in multiple Vagrantfiles to setup Openstack
# and libvirt provider details.
#
require 'ipaddr'
require 'json'
require 'open-uri'

if (Gem::Version.new('1.7.2') <= Gem.loaded_specs['vagrant'].version) and
   (Gem.loaded_specs['vagrant'].version <= Gem::Version.new('1.7.4'))
  STDERR.puts "Applying ansible provisioner patch."
  require_relative 'ansible_provisioner_patch'
end
require_relative 'fog_libvirt_patch'
require_relative 'guest_redhat_configure_networks_patch'

module Ardana
  class Config
    DEPLOYER_NODE = 'ARDANA'
    VMFACTORY_NODE = 'VMFACTORY'
    ARDANA_HYPERVISOR_NODE = 'ARDANA_HYPERVISOR'
    CONTROL_NODE = 'CONTROLLER'
    MIDCONTROL_NODE = 'MID_CONTROLLER'
    LITECONTROL_NODE = 'LITE_CONTROLLER'
    COMPUTE_NODE = 'COMPUTE'
    LITECOMPUTE_NODE = 'LITE_COMPUTE'
    OSD_NODE = 'OSD' # (Object Storage Device)
    VSA_NODE = 'VSA' # (VSA Storage Device)
    RGW_NODE = 'RGW' # (Swift and S3 API for Ceph)
    SWOBJ_NODE = 'SWOBJ' # (Swift object server)

    VM_MEMORY = {
      'build' => !!ENV["ARDANA_BUILD_MEMORY"] ? ENV["ARDANA_BUILD_MEMORY"] : 10240,
      'default' => 2048,
      DEPLOYER_NODE => 2048,
      VMFACTORY_NODE => !!ENV["ARDANA_VMF_MEMORY"] ? ENV["ARDANA_VMF_MEMORY"].to_i : 32768,
      ARDANA_HYPERVISOR_NODE => !!ENV["ARDANA_HV_MEMORY"] ? ENV["ARDANA_HV_MEMORY"].to_i : 32768,
      # CONTROL_NODE is currently used in deployerincloud & standard. These
      # controllers run all control servers. So they need more memory
      CONTROL_NODE => !!ENV["ARDANA_CCN_MEMORY"] ? ENV["ARDANA_CCN_MEMORY"].to_i : 15360,
      MIDCONTROL_NODE => !!ENV["ARDANA_CCN_MEMORY"] ? ENV["ARDANA_CCN_MEMORY"].to_i : 10240,
      LITECONTROL_NODE => !!ENV["ARDANA_CCN_MEMORY"] ? ENV["ARDANA_CCN_MEMORY"].to_i : 9216,
      COMPUTE_NODE => !!ENV["ARDANA_CPN_MEMORY"] ? ENV["ARDANA_CPN_MEMORY"].to_i : 6144,
      LITECOMPUTE_NODE => !!ENV["ARDANA_CPN_MEMORY"] ? ENV["ARDANA_CPN_MEMORY"].to_i : 4096,
      OSD_NODE => !!ENV["ARDANA_CON_MEMORY"] ? ENV["ARDANA_CON_MEMORY"].to_i : 4096,
      VSA_NODE => !!ENV["ARDANA_VSA_MEMORY"] ? ENV["ARDANA_VSA_MEMORY"].to_i : 12288,
      RGW_NODE => !!ENV["ARDANA_RGW_MEMORY"] ? ENV["ARDANA_RGW_MEMORY"].to_i : 4096,
      SWOBJ_NODE => !!ENV["ARDANA_SWOBJ_MEMORY"] ? ENV["ARDANA_SWOBJ_MEMORY"].to_i : 2048
    }

    VM_CPU = {
      'build' => !!ENV["ARDANA_BUILD_CPU"] ? ENV["ARDANA_BUILD_CPU"] : 8,
      'default' => 2,
      DEPLOYER_NODE => 4,
      VMFACTORY_NODE => !!ENV["ARDANA_VMF_CPU"] ? ENV["ARDANA_VMF_CPU"].to_i : 16,
      ARDANA_HYPERVISOR_NODE => !!ENV["ARDANA_HV_CPU"] ? ENV["ARDANA_HV_CPU"].to_i : 16,
      CONTROL_NODE => !!ENV["ARDANA_CCN_CPU"] ? ENV["ARDANA_CCN_CPU"].to_i : 4,
      MIDCONTROL_NODE => !!ENV["ARDANA_CCN_CPU"] ? ENV["ARDANA_CCN_CPU"].to_i : 4,
      LITECONTROL_NODE => !!ENV["ARDANA_CCN_CPU"] ? ENV["ARDANA_CCN_CPU"].to_i : 2,
      COMPUTE_NODE => !!ENV["ARDANA_CPN_CPU"] ? ENV["ARDANA_CPN_CPU"].to_i : 4,
      LITECOMPUTE_NODE => !!ENV["ARDANA_CPN_CPU"] ? ENV["ARDANA_CPN_CPU"].to_i : 2,
      OSD_NODE => !!ENV["ARDANA_CON_CPU"] ? ENV["ARDANA_CON_CPU"].to_i : 2,
      VSA_NODE => !!ENV["ARDANA_VSA_CPU"] ? ENV["ARDANA_VSA_CPU"].to_i : 2,
      RGW_NODE => !!ENV["ARDANA_RGW_CPU"] ? ENV["ARDANA_RGW_CPU"].to_i : 2,
      SWOBJ_NODE => !!ENV["ARDANA_SWOBJ_CPU"] ? ENV["ARDANA_SWOBJ_CPU"].to_i : 2
    }

    VM_FLAVOR = {
      'build' => 'standard.large',
      'default' => 'standard.xsmall',
      VMFACTORY_NODE => 'standard.xlarge',
      ARDANA_HYPERVISOR_NODE => 'standard.xlarge',
      DEPLOYER_NODE => 'standard.xsmall',
      CONTROL_NODE => ENV["ARDANA_CCN_FLAVOR"] || 'standard.medium',
      MIDCONTROL_NODE => ENV["ARDANA_CCN_FLAVOR"] || 'standard.medium',
      LITECONTROL_NODE => ENV["ARDANA_CCN_FLAVOR"] || 'standard.medium',
      COMPUTE_NODE => ENV["ARDANA_CPN_FLAVOR"] || 'standard.small',
      LITECOMPUTE_NODE => ENV["ARDANA_CPN_FLAVOR"] || 'standard.small',
      OSD_NODE => ENV["ARDANA_CON_FLAVOR"] || 'standard.small',
      VSA_NODE => ENV["ARDANA_VSA_FLAVOR"] || 'standard.medium',
      RGW_NODE => ENV["ARDANA_RGW_FLAVOR"] || 'standard.small',
      SWOBJ_NODE => ENV["ARDANA_SWOBJ_FLAVOR"] || 'standard.small'
    }

    VM_DISK = {
      VMFACTORY_NODE => ENV["ARDANA_VM_DISK"] || '70GB',
      ARDANA_HYPERVISOR_NODE => ENV["ARDANA_HV_DISK"] || '70GB',
      CONTROL_NODE => ENV["ARDANA_CCN_DISK"] || '20GB',
      MIDCONTROL_NODE => ENV["ARDANA_CCN_DISK"] || '20GB',
      LITECONTROL_NODE => ENV["ARDANA_CCN_DISK"] || '20GB',
      COMPUTE_NODE => ENV["ARDANA_CPN_DISK"] || '20GB',
      LITECOMPUTE_NODE => ENV["ARDANA_CPN_DISK"] || '20GB',
      OSD_NODE => ENV["ARDANA_CON_DISK"] || '11GB',
      VSA_NODE => ENV["ARDANA_VSA_DISK"] || '30GB',
      SWOBJ_NODE => ENV["ARDANA_SWOBJ_DISK"] || '20GB'
    }
    VM_EXTRA_DISKS = {
      VMFACTORY_NODE => ENV["ARDANA_VMF_EXTRA_DISKS"] || 5,
      ARDANA_HYPERVISOR_NODE => ENV["ARDANA_HV_EXTRA_DISKS"] || 5,
      CONTROL_NODE => ENV["ARDANA_CCN_EXTRA_DISKS"] || 5,
      MIDCONTROL_NODE => ENV["ARDANA_CCN_EXTRA_DISKS"] || 5,
      LITECONTROL_NODE => ENV["ARDANA_CCN_EXTRA_DISKS"] || 5,
      COMPUTE_NODE => ENV["ARDANA_CPN_EXTRA_DISKS"] || 1,
      LITECOMPUTE_NODE => ENV["ARDANA_CPN_EXTRA_DISKS"] || 1,
      OSD_NODE => ENV["ARDANA_CON_EXTRA_DISKS"] || 6,
      VSA_NODE => ENV["ARDANA_VSA_EXTRA_DISKS"] || 6,
      SWOBJ_NODE => ENV["ARDANA_SWOBJ_EXTRA_DISKS"] || 5
    }

    #
    # Initialize the configuration class
    def initialize(config)
      @config = config
      @dev_tool_path = File.expand_path(File.dirname(__FILE__) + "/..")
      @persistent_deployer_apt_cache = "persistent-apt-cache-v2.qcow2"
    end

    def get_product_branch()
      # Remove trailing newline also
      value = %x( git config --file $(git rev-parse --show-toplevel)/.gitreview --get gerrit.defaultbranch ).strip
      raise "Unknown defaultbranch" if value.empty?
      return value
    end

    def get_product_branch_cache()
      return File.absolute_path( ENV["HOME"] + "/.cache-ardana/" + get_product_branch().gsub('/', '_') )
    end

    def get_image_output_dir()
      return get_product_branch_cache() + "/images"
    end

    def get_release_artifact_dir()
      return get_product_branch_cache() + "/artifacts"
    end

    def initialize_baremetal(cloud_name)
      if !!ENV["ARDANA_SERVERS"]
        metal_cfg = ENV["ARDANA_SERVERS"]
      else
        cloud_cfg_dir = '2.0/ardana-ci/' + cloud_name + '/data/'

        local_base = "#@dev_tool_path/../ardana-input-model/" + cloud_cfg_dir
        metal_cfg = File.expand_path( local_base + 'servers.yml' )

        if not File.directory?(local_base) or !!ENV["ARDANA_REF_MODEL_TAG"]
          git_base = 'http://git.suse.provo.cloud/cgit/ardana/ardana-input-model/plain/' + cloud_cfg_dir
          git_branch = '?h=' + (ENV["ARDANA_REF_MODEL_TAG"] || get_product_branch())

          metal_cfg = git_base + 'servers.yml' + git_branch
        end
      end

      STDERR.puts "Servers details loaded from: " + metal_cfg

      metal_cfg = YAML.load open(metal_cfg)
      server_details = metal_cfg["servers"]
      # We skip any Virtual Control Plane VMs.
      server_details.delete_if { |serverInfo| serverInfo.key?('hypervisor-id') }
      return metal_cfg
    end

    def setup_iso(server: None, names: ["hlinux"])
      iso_files = []

      if names.include?("hlinux")
        if !!ENV["ARDANA_USE_RELEASE_ARTIFACT"]
          iso_file = get_release_artifact_dir() + "/#{ENV['ARDANA_USE_RELEASE_ARTIFACT']}"
          if !File.exists?(iso_file)
            iso_file = get_release_artifact_dir() + "/release.iso"
          end
          if !File.exists?(iso_file)
            raise "Run 'ansible-playbook -i hosts/localhost get-release-artifacts.yml' to get the relase ISO"
          end
          iso_files.push(iso_file)
        else
          iso_files.push( get_image_output_dir() + "/hlinux.iso" )
          if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
            raise "Run 'ansible-playbook -i hosts/localhost get-hlinux-iso.yml' to get the correct ISO"
          end
        end
      end

      if names.include?("rhel7")
        iso_files.push( get_image_output_dir() + "/rhel7.iso" )
        if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
          raise "Run 'ansible-playbook -i hosts/localhost get-rhel-artifacts.yml' to get the RHEL ISO"
        end
      end

      if names.include?("sles12")
        %w{ sles12.iso sles12sdk.iso }.each do |iso_name|
          iso_files.push(File.join(get_image_output_dir(), iso_name))
          if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
            raise "Run 'ansible-playbook -i hosts/localhost get-sles-artifacts.yml' to get the SLES ISOs"
          end
        end
      end

      server.vm.provider :libvirt do |libvirt, override|
        # vagrant-libvirt cannot merge blocks of storage, so need to add all isos
        # in the same block otherwise subsequent additions replace previous definitions
        iso_files.each do |iso_file|
          libvirt.storage :file, :device => :cdrom, :path => iso_file
        end
      end
    end

    def provision_deployer(server: None, name: "deployer", distros: [], extra_vars: {}, disks: [])
      # Provisioning
      # Add the pseudo host group defined in parallel-ansiblerepo-build.yml
      setup_vm(vm: server.vm, name: name, extra_vars: extra_vars, disks: disks)

      setup_iso(server: server, names: distros)

      server.vm.provision "ansible" do |ansible|
        ansible.playbook = "#@dev_tool_path/ansible/deployer-setup.yml"
        ansible.host_key_checking = false
        ansible.limit = name + ",repo_parallel"
        if extra_vars
          ansible.extra_vars = extra_vars
        end
      end
    end
    private :provision_deployer

    def add_server_group(modifier: 0, cloud_name: None, deployer_node: None)
      metal_cfg = initialize_baremetal(cloud_name)
      server_details = metal_cfg["servers"]

      ip_offset = 1
      prev_node_type = ""

      rhel_compute_nodes = ENV.fetch("ARDANA_RHEL_COMPUTE_NODES", "").split(":")
      rhel_compute_all = ENV.fetch("ARDANA_RHEL_COMPUTE", "") == "1"
      sles_compute_nodes = ENV.fetch("ARDANA_SLES_COMPUTE_NODES", "").split(":")
      sles_compute_all = ENV.fetch("ARDANA_SLES_COMPUTE", "") == "1"

      deployer_info = server_details.find { |server| server["id"] == deployer_node }
      distributions = server_details.map { |server| server["os-dist"] || "hlinux" }.uniq
      distributions = distributions | ["rhel7"] if ! rhel_compute_nodes.empty? || rhel_compute_all
      distributions = distributions | ["sles12"] if ! sles_compute_nodes.empty? || sles_compute_all

      server_details.each do |serverInfo|
        use_release_artifact = !!ENV["ARDANA_USE_RELEASE_ARTIFACT"]

        map_role = serverInfo["role"]
        if map_role.match("COMPUTE")
          # check for LITE version
          if map_role.match("LITE-COMPUTE")
            node_type=LITECOMPUTE_NODE
          else
            node_type=COMPUTE_NODE
          end
          if ( rhel_compute_nodes.include? serverInfo["id"] ) || rhel_compute_all
            serverInfo["os-dist"] = "rhel7"
            # RHEL support doesn't yet support booting of a release RHEL image.
            use_release_artifact = false
          end
          if ( sles_compute_nodes.include? serverInfo["id"] ) || sles_compute_all
            serverInfo["os-dist"] = "sles12"
            use_release_artifact = false
          end
        elsif map_role.match("VMFACTORY")
          node_type=VMFACTORY_NODE
        elsif map_role.match("ARDANA-HYPERVISOR")
          node_type=ARDANA_HYPERVISOR_NODE
        elsif map_role.match("CONTROLLER")
          # check for LITE version
          if map_role.match("LITE-CONTROLLER")
            node_type=LITECONTROL_NODE
          else
            node_type=CONTROL_NODE
          end
        elsif map_role.match("OSD")
          node_type=OSD_NODE
        elsif map_role.match("VSA")
          node_type=VSA_NODE
        elsif map_role.match("ARDANA")
          node_type=DEPLOYER_NODE
        elsif map_role.match("RGW")
          node_type=RGW_NODE
        elsif map_role.match("SWOBJ")
          node_type=SWOBJ_NODE
        else
          # Matches the different node_type for the midsize which needs less
          # memory than the standard.
          node_type=MIDCONTROL_NODE
        end

        server_name = serverInfo["id"]
        box_name = (serverInfo["os-dist"] || "hlinux") +  "box"

        @config.vm.define server_name do |server|
          set_vm_box(vm: server.vm,
                     box: box_name,
                     use_release_artifact: use_release_artifact)
          add_access_network(vm: server.vm)

          # Reserve a VIP address for each node type in Ardana
          if node_type != prev_node_type
            ip_offset += 1
            prev_node_type = node_type
          end

          add_ardana_network(vm: server.vm, ip: 1 + ip_offset + modifier)
          add_pxe_network(vm: server.vm, ip: serverInfo["ip-addr"], mac: serverInfo["mac-addr"])

          add_idle_networks(vm: server.vm, count: 6)

          set_vm_hardware(vm: server.vm, type: node_type)

          disks = []
          if deployer_node == server_name
            # This is strange. I don't exactly trust vagrant-libvirtd / libvirtd
            # to be doing the right thing here. But we this puts the persistent
            # cache to th start of the disks, but inside the deployer I see this
            # as the last device - sdg
            disks.push({
                         :bus => "scsi",
                         :size => "10G",
                         :path => @persistent_deployer_apt_cache,
                         :allow_existing => true
                       })
          end
          # Add the requested number of disks for this node type
          if !!VM_DISK[node_type]
            (1..VM_EXTRA_DISKS[node_type]).each do |i|
              disks.push({:bus => "scsi", :size => VM_DISK[node_type] })
            end
          end

          # Provisioning VM
          if deployer_node == server_name
            device = "/dev/sd#{( 10 + disks.length ).to_s 36}"
            provision_deployer(server: server,
                               name: server_name,
                               distros: distributions,
                               extra_vars: {"persistent_apt_device" => device,
                                            "persistent_apt_cache_volume" => @persistent_deployer_apt_cache},
                               disks: disks)
          else
            setup_vm(vm: server.vm, name: server_name,
                     extra_vars: {"deployer_address" => deployer_info["ip-addr"]},
                     disks: disks)
          end

          ip_offset += 1
        end
      end
    end

    def add_build
      machines = ["build-hlinux"]
      # dirty hack to be able to have vagrant tell us what it knows about already
      active_machines = ObjectSpace.each_object(Vagrant::Environment).first.active_machines
      if !ENV.fetch("ARDANA_RHEL_ARTIFACTS", "").empty? or
          active_machines.map { |machine, _| machine.to_s == "build-rhel7" }.any?
        machines << "build-rhel7"
      end
      if !ENV.fetch("ARDANA_SLES_ARTIFACTS", "").empty? or
          active_machines.map { |machine, _| machine.to_s == "build-sles12" }.any?
        machines << "build-sles12"
      end

      machines.each do |machine|
        @config.vm.define machine do |build|
          distro = machine.split("-").last

          box_name = !!ENV["ARDANA_OS_DIST"] ? ENV["ARDANA_OS_DIST"] : "#{distro}box"

          # Add local volume on /dev/vda
          if distro != "hlinux"
            ccache_path = "persistent-ccache-#{distro}.qcow2"
          else
            ccache_path = "persistent-ccache.qcow2"
          end

          set_vm_box(vm: build.vm, box: box_name)
          add_access_network(vm: build.vm)

          # Provisioning
          setup_vm(vm: build.vm, name: machine, playbook: "vagrant-setup-build-vm",
                   extra_vars: {"persistent_cache_qcow2" => ccache_path} )

          set_vm_hardware(vm: build.vm, type: 'build')

          build.vm.provider :libvirt do |libvirt, override|
            libvirt.storage :file, :path => ccache_path, :allow_existing => true, :size => '50G'
          end

          setup_iso(server: build, names: [distro])

          set_proxy_config
        end
      end
    end

    def setup_vm(vm: None, name: None, playbook: "vagrant-setup-vm", extra_vars: {}, disks: [])
      vm.provider :libvirt do |libvirt, override|
        disks.each do |disk|
          libvirt.storage :file, disk
        end

        # BUG-5015 ensure that management network for build machines is
        # different to cloud machines to prevent accidental replacement
        # or overwrite of network configuration when bringing both
        # up at the same time.
        if name.start_with?("build-")
          libvirt.management_network_name = "vagrant-libvirt-build"
          libvirt.management_network_address = "192.168.120.0/24"
        end
      end

      vm.provision :ansible do |ansible|
        ansible.playbook = "#@dev_tool_path/ansible/#{playbook}.yml"
        ansible.host_key_checking = false
        ansible.verbose = true
        if extra_vars
          ansible.extra_vars = extra_vars
        end
      end

      if ENV.fetch("CI", "no").downcase == "yes"
        vm.provider :libvirt do |libvirt, override|
          libvirt.serial :type => "file",
            :source => {
              :path => File.absolute_path(
                ( ENV['CONSOLE_LOG_DIR'] || "#{@dev_tool_path}/logs/console" ) + "/#{name}.log")
            }
        end
      end
    end

    def set_vm_box(vm: None, box: None, use_release_artifact: false)
      if openstack?
        vm.box = 'dummy'
        vm.box_url =
            'https://github.com/cloudbau/vagrant-openstack-plugin/raw/master/dummy.box'
      else
        vm.box = box

        # This sets the box for non-openstack vagrant configurations
        # We check for the hlinuxbox.json file so that developers who
        # haven't yet rebuild their hlinux image will continue to still work.
        if use_release_artifact
          box_file = get_release_artifact_dir() + "/#{ENV['ARDANA_USE_RELEASE_ARTIFACT']}-hlinuxbox.json"
          if !File.exists?(box_file)
            box_file = get_release_artifact_dir() + "/release-hlinuxbox.json"
          end
        else
          box_file = "#@dev_tool_path/#{box}.json"
        end

        if File.exists?(box_file)
          box_json = File.read(box_file)
          box_json = JSON.parse(box_json)

          vm.box_url = "file://" + box_file
          vm.box_version = box_json["versions"][0]["version"]
        end

        # don't override a setting provided by the box itself, but ensure
        # old hlinuxbox images without this, will still boot
        if !vm.guest.kind_of? String and vm.box == "hlinuxbox"
          vm.guest = :debian
        end
      end
    end

    def set_vm_hardware(vm: None, type: 'default')
      vm.provider "virtualbox" do |vb, override|
        vb.memory = VM_MEMORY[type]
        vb.cpus = VM_CPU[type]
      end

      vm.provider "libvirt" do |domain, override|
        domain.memory = VM_MEMORY[type]
        domain.cpus = VM_CPU[type]
        domain.disk_bus = 'scsi'
        domain.volume_cache = 'unsafe'
        domain.nested = true
        domain.cpu_mode = 'host-passthrough'
        domain.machine_virtual_size = 120
      end

      vm.provider "openstack" do |os, override|
        os.flavor = /#{VM_FLAVOR[type]}/
      end
    end

    def add_access_network(vm: None)
      # Only add this is the provider in use is openstack - other providers already automatically
      # add a network for vagrant access
      if openstack?
        vm.network :public_network, type: 'dhcp'
      end
    end

    def add_ardana_network(vm: None, ip: None)
      opts = {
        libvirt__dhcp_enabled: false,
        auto_config: false,
        ip: "192.168.245.#{ip}",
        netmask: "255.255.255.0",
      }

      if !!ENV["ARDANA_ARDANA_INTF"]
        # Use the ARDANA_ARDANA_INTF interface in bridged mode
        opts[:dev] = ENV["ARDANA_ARDANA_INTF"]
        opts[:type] = "bridge"
        vm.network :public_network, opts
      else
        vm.network :private_network, opts
      end
    end

    def add_pxe_network(vm: None, ip: None, mac: None)
      opts = {
        libvirt__dhcp_enabled: false,
        auto_config: true,
        ip: "#{ip}",
        netmask: "255.255.255.0",
        mac: "#{mac}",
      }

      if !!ENV["ARDANA_PXE_INTF"]
        # Use the ARDANA_PXE_INTF interface in bridged mode
        opts[:dev] = ENV["ARDANA_PXE_INTF"]
        opts[:type] = "bridge"
        vm.network :public_network, opts
      else
        vm.network :private_network, opts
      end
    end

    def add_idle_networks(vm: None, count: 1)
      (1..count).each do |ip|
         # even with auto_config:false, ip is required (using link local)
         opts = {
          libvirt__dhcp_enabled: false,
          auto_config: false,
          ip: "169.254.#{ip}.2",
        }

        if !!ENV["ARDANA_IDLE_INTF_#{ip}"]
          # Use the "ARDANA_IDLE_INTF_#{ip}" interface in bridged mode
          opts[:dev] = ENV["ARDANA_IDLE_INTF_#{ip}"]
          opts[:type] = "bridge"
          vm.network :public_network, opts
        else
          vm.network :private_network, opts
        end
      end
    end

    def set_ssh_config
      # Created hosts access info
      #   username and password for internal images
      #   key for cloud instances
      if openstack?
        @config.ssh.username = 'ubuntu'
        @config.ssh.private_key_path = ENV["PRIVATE_KEY"] if ENV["PRIVATE_KEY"]
      else
        if !@config.ssh.username.kind_of? String
          # if the box already defines a username, use it's credentials
          @config.ssh.username = ENV["ARDANAUSER"] ||= "stack"
          @config.ssh.password = ENV["ARDANAUSER"] ||= "stack"
        end
      end
    end

    def set_provider_config
      @config.vm.provider :libvirt do |libvirt|
        libvirt.uri = "qemu:///system"
        libvirt.driver = "kvm"
        libvirt.host = "localhost"
        libvirt.connect_via_ssh = false
        # allow users to override the pool used via a user Vagrantfile
        libvirt.storage_pool_name ||= "default"
      end

      @config.vm.provider :virtualbox do |virtualbox|
        virtualbox.gui = true
      end

      @config.vm.provider :openstack do |os|
        set_openstack_provider(provider: os)
      end
    end

    def set_openstack_provider(provider: None)
      provider.username         = ENV["OS_USERNAME"]
      provider.api_key          = ENV["OS_PASSWORD"]
      provider.tenant           = ENV["OS_TENANT_NAME"]
      provider.flavor           = /#{VM_FLAVOR['default']}/
      provider.image            = /Ubuntu Server 14.10 \(amd64 20141022.3\) - Partner Image/
      provider.endpoint         = ENV["OS_ENDPOINT"]
      provider.keypair_name     = ENV["OS_KEYPAIR"]
      provider.ssh_username     = "ubuntu"
      provider.region           = ENV["OS_REGION"]
      provider.metadata         = {"key" => "value"}
      provider.security_groups  = ['default']
      provider.networks         = [ 'vagrant-access', 'ardana-clm', 'ardana-pxe' ]
      provider.floating_ip      = :auto
      provider.floating_ip_pool = ENV["OS_FIP_POOL"]
    end

    def set_vm_config
      @config.vm.synced_folder ".", "/vagrant", disabled: true
    end

    def set_proxy_config
      # If we don't have the proxyconf plugin, we can't auto-set proxies
      if not Vagrant.has_plugin?("vagrant-proxyconf")
        puts "No proxyconf plugin - can't set proxies"
        return
      end
      # We don't set the proxy configuration if using openstack,
      # as cloud instances direct connect
      # no_proxy is now set by an osconfig ansible task
      if openstack?
        puts "Not configuring proxies for cloud instances"
        return
      end
      @config.proxy.http = ENV["http_proxy"] if ENV["http_proxy"]
      @config.proxy.https = ENV["https_proxy"] if ENV["https_proxy"]
      @config.proxy.no_proxy = ENV["no_proxy"] if ENV["no_proxy"]

      # BUG-626 - override the http proxies for now. We are in effect
      # configuring apt to go direct to apt host so proxies are been
      # bypassed.
      @config.apt_proxy.http = ""
      @config.apt_proxy.https = ""
    end

    #
    # An OpenStack provider?
    def openstack?
      provider == "openstack"
    end

    # XXX: This function should be made more complete as appropriate
    def provider
      ENV['VAGRANT_DEFAULT_PROVIDER'] || ""
    end

    def generate_mac(ip)
      prefix = 0xEE0000000000
      ip = IPAddr.new(ip)
      mac = prefix + ip.to_i()
      return mac.to_s(16)
    end
  end
end
