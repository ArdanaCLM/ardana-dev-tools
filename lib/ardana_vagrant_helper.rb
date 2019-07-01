#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017-2018 SUSE LLC
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
  STDERR.puts "Applying ansible patches for Vagrant 1.7.x."
  require_relative 'ansible_provisioner_patch'
  require_relative 'guest_redhat_configure_networks_patch'
end
if Gem.loaded_specs['fog'] and
   (Gem.loaded_specs['fog-libvirt'].version == Gem::Version.new('0.3.0'))
  STDERR.puts "Applying fog-libvirt 0.3.0 patch"
  require_relative 'fog_libvirt_patch'
end

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

    # Node classes used by the dac-* models
    DAC_CTRL_NODE = 'DAC_CTRL'
    DAC_COMP_NODE = 'DAC_COMP'

    # Node classes used by the std-* models
    STD_DPLY_NODE = 'STD_ARDANA'
    STD_CTRL_NODE = 'STD_CTRL'
    STD_OSC_NODE = 'STD_OSC'
    STD_DBMQ_NODE = 'STD_DBMQ'
    STD_MML_NODE = 'STD_MML'
    STD_COMP_NODE = 'STD_COMP'

    VM_MEMORY = {
      # Node classes used by the dac-* models
      DAC_CTRL_NODE => !!ENV["ARDANA_DCTRL_MEMORY"] ? ENV["ARDANA_DCTRL_MEMORY"].to_i : 30720,
      DAC_COMP_NODE => !!ENV["ARDANA_DCOMP_MEMORY"] ? ENV["ARDANA_DCOMP_MEMORY"].to_i : 6144,

      'default' => 2048,
      DEPLOYER_NODE => 2048,
      VMFACTORY_NODE => !!ENV["ARDANA_VMF_MEMORY"] ? ENV["ARDANA_VMF_MEMORY"].to_i : 32768,
      ARDANA_HYPERVISOR_NODE => !!ENV["ARDANA_HV_MEMORY"] ? ENV["ARDANA_HV_MEMORY"].to_i : 32768,
      # CONTROL_NODE is currently used in deployerincloud & standard. These
      # controllers run all control servers. So they need more memory
      CONTROL_NODE => !!ENV["ARDANA_CCN_MEMORY"] ? ENV["ARDANA_CCN_MEMORY"].to_i : 25600,
      MIDCONTROL_NODE => !!ENV["ARDANA_CCN_MEMORY"] ? ENV["ARDANA_CCN_MEMORY"].to_i : 10240,
      LITECONTROL_NODE => !!ENV["ARDANA_CCN_MEMORY"] ? ENV["ARDANA_CCN_MEMORY"].to_i : 12288,
      COMPUTE_NODE => !!ENV["ARDANA_CPN_MEMORY"] ? ENV["ARDANA_CPN_MEMORY"].to_i : 6144,
      LITECOMPUTE_NODE => !!ENV["ARDANA_CPN_MEMORY"] ? ENV["ARDANA_CPN_MEMORY"].to_i : 5120,
      OSD_NODE => !!ENV["ARDANA_CON_MEMORY"] ? ENV["ARDANA_CON_MEMORY"].to_i : 4096,
      VSA_NODE => !!ENV["ARDANA_VSA_MEMORY"] ? ENV["ARDANA_VSA_MEMORY"].to_i : 12288,
      RGW_NODE => !!ENV["ARDANA_RGW_MEMORY"] ? ENV["ARDANA_RGW_MEMORY"].to_i : 4096,
      SWOBJ_NODE => !!ENV["ARDANA_SWOBJ_MEMORY"] ? ENV["ARDANA_SWOBJ_MEMORY"].to_i : 2048,

      # Node classes used by std-* models
      STD_DPLY_NODE => !!ENV["ARDANA_SDPLY_MEMORY"] ? ENV["ARDANA_SDPLY_MEMORY"].to_i : 1536,
      STD_CTRL_NODE => !!ENV["ARDANA_SCTRL_MEMORY"] ? ENV["ARDANA_SCTRL_MEMORY"].to_i : 25600,
      STD_OSC_NODE => !!ENV["ARDANA_SOSC_MEMORY"] ? ENV["ARDANA_SOSC_MEMORY"].to_i : 13824,
      STD_DBMQ_NODE => !!ENV["ARDANA_SDBMQ_MEMORY"] ? ENV["ARDANA_SDBMQ_MEMORY"].to_i : 3072,
      STD_MML_NODE => !!ENV["ARDANA_SMML_MEMORY"] ? ENV["ARDANA_SMML_MEMORY"].to_i : 8192,
      STD_COMP_NODE => !!ENV["ARDANA_SCMP_MEMORY"] ? ENV["ARDANA_SCMP_MEMORY"].to_i : 6144
    }

    VM_CPU = {
      # Node classes used by the dac-* models
      DAC_CTRL_NODE => !!ENV["ARDANA_DCTRL_CPU"] ? ENV["ARDANA_DCTRL_CPU"].to_i : 4,
      DAC_COMP_NODE => !!ENV["ARDANA_DCOMP_CPU"] ? ENV["ARDANA_DCOMP_CPU"].to_i : 4,

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
      SWOBJ_NODE => !!ENV["ARDANA_SWOBJ_CPU"] ? ENV["ARDANA_SWOBJ_CPU"].to_i : 2,

      # Node classes used by std-* models
      STD_DPLY_NODE =>  !!ENV["ARDANA_SDPLY_CPU"] ? ENV["ARDANA_SDPLY_CPU"].to_i : 2,
      STD_CTRL_NODE => !!ENV["ARDANA_SCTRL_CPU"] ? ENV["ARDANA_SCTRL_CPU"].to_i : 4,
      STD_OSC_NODE => !!ENV["ARDANA_SOSC_CPU"] ? ENV["ARDANA_SOSC_CPU"].to_i : 2,
      STD_DBMQ_NODE => !!ENV["ARDANA_SDBMQ_CPU"] ? ENV["ARDANA_SDBMQ_CPU"].to_i : 2,
      STD_MML_NODE => !!ENV["ARDANA_SMML_CPU"] ? ENV["ARDANA_SMML_CPU"].to_i : 2,
      STD_COMP_NODE => !!ENV["ARDANA_SCMP_CPU"] ? ENV["ARDANA_SCMP_CPU"].to_i : 2
    }

    VM_FLAVOR = {
      # Node classes used by the dac-* models
      DAC_CTRL_NODE => !!ENV["ARDANA_DCTRL_FLAVOR"] || 'standard.medium',
      DAC_COMP_NODE => !!ENV["ARDANA_DCOMP_FLAVOR"] || 'standard.small',

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
      SWOBJ_NODE => ENV["ARDANA_SWOBJ_FLAVOR"] || 'standard.small',

      # Node classes used by std-* models
      STD_DPLY_NODE => ENV["ARDANA_SDPLY_FLAVOR"] || 'standard.xsmall',
      STD_CTRL_NODE => ENV["ARDANA_SCTRL_FLAVOR"] || 'standard.medium',
      STD_OSC_NODE => ENV["ARDANA_SOSC_FLAVOR"] || 'standard.small',
      STD_DBMQ_NODE => ENV["ARDANA_SDBMQ_FLAVOR"] || 'standard.small',
      STD_MML_NODE => ENV["ARDANA_SMML_FLAVOR"] || 'standard.small',
      STD_COMP_NODE => ENV["ARDANA_SCMP_FLAVOR"] || 'standard.small'
    }

    VM_DISK = {
      # Node classes used by the dac-* models
      DAC_CTRL_NODE => !!ENV["ARDANA_DCTRL_DISK"] || '20GB',
      DAC_COMP_NODE => !!ENV["ARDANA_DCOMP_DISK"] || '20GB',

      VMFACTORY_NODE => ENV["ARDANA_VM_DISK"] || '70GB',
      ARDANA_HYPERVISOR_NODE => ENV["ARDANA_HV_DISK"] || '70GB',
      CONTROL_NODE => ENV["ARDANA_CCN_DISK"] || '20GB',
      MIDCONTROL_NODE => ENV["ARDANA_CCN_DISK"] || '20GB',
      LITECONTROL_NODE => ENV["ARDANA_CCN_DISK"] || '20GB',
      COMPUTE_NODE => ENV["ARDANA_CPN_DISK"] || '20GB',
      LITECOMPUTE_NODE => ENV["ARDANA_CPN_DISK"] || '20GB',
      OSD_NODE => ENV["ARDANA_CON_DISK"] || '11GB',
      VSA_NODE => ENV["ARDANA_VSA_DISK"] || '30GB',
      SWOBJ_NODE => ENV["ARDANA_SWOBJ_DISK"] || '20GB',

      # Node classes used by std-* models
      STD_CTRL_NODE => ENV["ARDANA_SCTRL_DISK"] || '20GB',
      STD_OSC_NODE => ENV["ARDANA_SOSC_DISK"] || '20GB',
      STD_DBMQ_NODE => ENV["ARDANA_SDBMQ_DISK"] || '20GB',
      STD_MML_NODE => ENV["ARDANA_SMML_DISK"] || '20GB',
      STD_COMP_NODE => ENV["ARDANA_SCMP_DISK"] || '20GB'
    }

    VM_EXTRA_DISKS = {
      # Node classes used by the dac-* models
      DAC_CTRL_NODE => !!ENV["ARDANA_DCTRL_EXTRA_DISKS"] || 5,
      DAC_COMP_NODE => !!ENV["ARDANA_DCOMP_EXTRA_DISKS"] || 1,

      VMFACTORY_NODE => ENV["ARDANA_VMF_EXTRA_DISKS"] || 5,
      ARDANA_HYPERVISOR_NODE => ENV["ARDANA_HV_EXTRA_DISKS"] || 5,
      CONTROL_NODE => ENV["ARDANA_CCN_EXTRA_DISKS"] || 5,
      MIDCONTROL_NODE => ENV["ARDANA_CCN_EXTRA_DISKS"] || 5,
      LITECONTROL_NODE => ENV["ARDANA_CCN_EXTRA_DISKS"] || 5,
      COMPUTE_NODE => ENV["ARDANA_CPN_EXTRA_DISKS"] || 1,
      LITECOMPUTE_NODE => ENV["ARDANA_CPN_EXTRA_DISKS"] || 1,
      OSD_NODE => ENV["ARDANA_CON_EXTRA_DISKS"] || 6,
      VSA_NODE => ENV["ARDANA_VSA_EXTRA_DISKS"] || 6,
      SWOBJ_NODE => ENV["ARDANA_SWOBJ_EXTRA_DISKS"] || 5,

      # Node classes used by std-* models
      STD_CTRL_NODE => ENV["ARDANA_SCTRL_EXTRA_DISKS"] || 5,
      STD_OSC_NODE => ENV["ARDANA_SOSC_EXTRA_DISKS"] || 5,
      STD_DBMQ_NODE => ENV["ARDANA_SDBMQ_EXTRA_DISKS"] || 5,
      STD_MML_NODE => ENV["ARDANA_SMML_EXTRA_DISKS"] || 5,
      STD_COMP_NODE => ENV["ARDANA_SCMP_EXTRA_DISKS"] || 1,
    }

    def _ip_networks_split(env_var_name, default_value)
      env_var_value = ENV.fetch(env_var_name, "")

      if env_var_value.empty?
        return default_value
      end

      return env_var_value.split(",")
    end

    #
    # Initialize the configuration class
    def initialize(config)
      @config = config
      @metal_cfg = nil
      @dev_tool_path = File.expand_path(File.join(File.dirname(__FILE__), "/.."))
      @git_uri_base = 'http://git.ci.prv.suse.net/cgit/ardana/'
      @persistent_deployer_apt_cache = "persistent-apt-cache-v2.qcow2"
      @ardana = {
        :attach_isos => !ENV.fetch("ARDANA_ATTACH_ISOS", "").empty?,
        :cloud => {
          :version => ENV.fetch("ARDANA_CLOUD_VERSION", "9"),
          :artifacts => !ENV.fetch("ARDANA_CLOUD_ARTIFACTS", "").empty?
        },
        :debug => !ENV.fetch("ARDANA_DEBUG", "").empty?,
        :ip => {
          :v4 => _ip_networks_split("ARDANA_IPV4_NETWORKS", [*0..8].map(&:to_s)),
          :v6 => _ip_networks_split("ARDANA_IPV6_NETWORKS", [])
        },
        :rhel => {
          :artifacts => !ENV.fetch("ARDANA_RHEL_ARTIFACTS", "").empty?,
          :compute => !ENV.fetch("ARDANA_RHEL_COMPUTE", "").empty?,
          :compute_nodes => ENV.fetch("ARDANA_RHEL_COMPUTE_NODES", "").split(":")
        },
        :sles => {
          :artifacts => !ENV.fetch("ARDANA_SLES_ARTIFACTS", "").empty?,
          :major => ENV.fetch("ARDANA_SLES_MAJOR", "12"),
          :sp => ENV.fetch("ARDANA_SLES_SP", "3"),
          :compute => !ENV.fetch("ARDANA_SLES_COMPUTE", "").empty?,
          :compute_nodes => ENV.fetch("ARDANA_SLES_COMPUTE_NODES", "").split(":"),
        }
      }
      _sles_version = "sles#{@ardana[:sles][:major]}"
      _sles_version << "sp#{@ardana[:sles][:sp]}" if @ardana[:sles][:sp].to_i > 0
      @distro_map = {
        "sles" => {
          :version => _sles_version
        },
        "rhel" => {
          :version => "rhel7"
        }
      }
    end

    def get_product_branch()
      # Remove trailing newline also
      value = %x( git -C #{@dev_tool_path} config --file $(git -C #{@dev_tool_path} rev-parse --show-toplevel)/.gitreview --get gerrit.defaultbranch ).strip
      raise "Unknown defaultbranch" if value.empty?
      return value
    end

    def get_product_branch_cache()
      return File.absolute_path( ENV["HOME"] + "/.cache-ardana/" + get_product_branch().gsub('/', '_') )
    end

    def get_image_output_dir()
      return get_product_branch_cache() + "/images"
    end

    # adt ==> ardana-dev-tools
    def get_adt_model_path(cloud_name)
      return File.join('ardana-vagrant-models', cloud_name + '-vagrant', 'input-model')
    end

    def get_adt_model_uri(cloud_name, branch, yml_path)
      repo_path = File.join('ardana-dev-tools', get_adt_model_path(cloud_name))
      branch_spec = '?h=' + branch
      return @git_uri_base + repo_path + '/' + yml_path + branch_spec
    end

    # aim ==> ardana-input-model
    def get_aim_model_path(cloud_name)
      return File.join('2.0', 'ardana-ci', cloud_name)
    end

    def get_aim_model_uri(cloud_name, branch, yml_path)
      repo_path = File.join('ardana-input-model', get_aim_model_path(cloud_name))
      branch_spec = '?h=' + branch
      return @git_uri_base + repo_path + '/' + yml_path + branch_spec
    end

    def get_model_uris(cloud_name, git_branch, yml_path)
      model_uris = []

      # If environment override specified, add it first
      if !! ENV["ARDANA_SERVERS"]
        model_uris.push(ENV["ARDANA_SERVERS"])
      end

      # We prefer local file system sources over remote repos, trying
      # locally in the a-d-t clone area and then in any a-i-m clone
      # beside it.
      model_uris.push(File.join(@dev_tool_path,
                                get_adt_model_path(cloud_name),
                                yml_path))
      model_uris.push(File.expand_path(File.join(@dev_tool_path, '..',
                                                 'ardana-input-model',
                                                 get_aim_model_path(cloud_name),
                                                 yml_path)))

      # input models may be in upstream a-d-t git repo for Cloud 9+
      if @ardana[:cloud][:version].to_i > 8
        model_uris.push(get_adt_model_uri(cloud_name, git_branch, yml_path))
      end

      # Finally try looking in the upstream a-i-m git repo
      model_uris.push(get_aim_model_uri(cloud_name, git_branch, yml_path))

      return model_uris
    end

    def get_metal_cfg(cloud_name, git_branch, yml_path = 'data/servers.yml')
      # if we already have loaded the metal_cfg previously, reuse that
      return @metal_cfg if not @metal_cfg.nil?

      # generate list of possible locations for servers.yml and iterate
      # through them until we find one that YAML.load()'s successfully
      # and return the result
      servers_uris = get_model_uris(cloud_name, git_branch, yml_path)

      # iterate over list of possible servers.yml locations
      servers_uris.each do |servers_yml|
        # skip nil/empty entries
        next if (servers_yml.nil? || servers_yml.empty?)

        begin
          metal_cfg = YAML.load(open(servers_yml))

          STDERR.puts "Servers details loaded from: " + servers_yml

          # record the servers_yml that works in the metal_cfg
          metal_cfg['_servers_yml_uri'] = servers_yml

          # save the result for future reference
          @metal_cfg = metal_cfg

          if !metal_cfg.key?("ci_settings")
            metal_cfg["ci_settings"] = {}
          end

          # we succeeded in loading this one so return the result
          return metal_cfg
        rescue
          # Catch and ignore the exception
          STDERR.puts "Failed to YAML.load('#{servers_yml}')" if @ardana[:debug]
        end
      end

      raise "Unable to locate a servers.yml for cloud '#{cloud_name}' on branch '#{git_branch}'"
    end

    def determine_node_type(role_name)
      if role_name.match("COMPUTE")
        # check for LITE version
        if role_name.match("LITE-COMPUTE")
          node_type=LITECOMPUTE_NODE
        elsif role_name.match("STD-COMPUTE")
          node_type=STD_COMP_NODE
        elsif role_name.match("DAC-COMPUTE")
          node_type=DAC_COMP_NODE
        else
          node_type=COMPUTE_NODE
        end
      elsif role_name.match("VMFACTORY")
        node_type=VMFACTORY_NODE
      elsif role_name.match("ARDANA-HYPERVISOR")
        node_type=ARDANA_HYPERVISOR_NODE
      elsif role_name.match("CONTROLLER")
        # check for LITE version
        if role_name.match("LITE-CONTROLLER")
          node_type=LITECONTROL_NODE
        # check for STD-OSC version
        elsif role_name.match("STD-OSC-CONTROLLER")
          node_type=STD_OSC_NODE
        # check for STD-DBMQ version
        elsif role_name.match("STD-DBMQ-CONTROLLER")
          node_type=STD_DBMQ_NODE
        # check for STD-MML version
        elsif role_name.match("STD-MML-CONTROLLER")
          node_type=STD_MML_NODE
        elsif role_name.match("DAC-CONTROLLER")
          node_type=DAC_CTRL_NODE
        else
          node_type=CONTROL_NODE
        end
      elsif role_name.match("OSD")
        node_type=OSD_NODE
      elsif role_name.match("VSA")
        node_type=VSA_NODE
      elsif role_name.match("ARDANA")
        # check for STD version
        if role_name.match("STD-ARDANA")
          node_type=STD_DPLY_NODE
        else
          node_type=DEPLOYER_NODE
        end
      elsif role_name.match("RGW")
        node_type=RGW_NODE
      elsif role_name.match("SWOBJ")
        node_type=SWOBJ_NODE
      else
        # Matches the different node_type for the midsize which needs less
        # memory than the standard.
        node_type=MIDCONTROL_NODE
      end
    end

    def initialize_baremetal(cloud_name)

      # determine which branch we need to use
      if !!ENV["ARDANA_REF_MODEL_TAG"]
        # override reference tag specifed
        git_branch_name = ENV["ARDANA_REF_MODEL_TAG"]
      elsif @ardana[:cloud][:version].to_i == 8
        # if specifying Cloud8 on master
        git_branch_name = 'stable/pike'
      elsif
        git_branch_name = get_product_branch()
      end

      # get the (possibly cached) servers.yml configuration data
      metal_cfg = get_metal_cfg(cloud_name, git_branch_name)

      server_details = metal_cfg["servers"]
      ci_settings = metal_cfg["ci_settings"]

      # We skip any Virtual Control Plane VMs.
      server_details.delete_if { |serverInfo| serverInfo.key?('hypervisor-id') }

      # blanket node class directives
      rhel_compute_all = @ardana[:rhel][:compute]
      sles_compute_all = @ardana[:sles][:compute]

      # identify potential node specific overrides
      rhel_nodes = @ardana[:rhel][:compute_nodes]
      sles_nodes = @ardana[:sles][:compute_nodes]

      # setup unique VNC ports for each server
      vnc_base = 5910  # Ardana vagrant VMs start at 5910
      server_details.each_with_index do |serverInfo, i|
        node_role = serverInfo["role"]
        if ci_settings.key?(node_role)
          STDERR.puts "Using input model hardware settings for #{serverInfo['id'].inspect}"
          hardware_setup = ci_settings[node_role]
        else
          STDERR.puts "Using helper hardware settings for #{serverInfo['id'].inspect}"
          node_type = determine_node_type(node_role)
          hardware_setup = {
            'memory' => VM_MEMORY[node_type],
            'cpus' => VM_CPU[node_type],
            'disks' => {
              'boot' => {
                'size_gib' => 200
              }
            },
            'flavor' => VM_FLAVOR[node_type]
          }
          if VM_EXTRA_DISKS.key?(node_type)
            hardware_setup['disks']['extras'] = {
              'count' => VM_EXTRA_DISKS[node_type],
              'size_gib' => VM_DISK[node_type]
            }
          end
        end
        serverInfo["hardware"] = hardware_setup

        if !serverInfo.key?("graphics_port")
          serverInfo["graphics_port"] = vnc_base + i
        end

        # if no os-dist is set, and an override exists, initialise it
        if !serverInfo.key?("os-dist")
          distro = ""

          if serverInfo["role"].match("CONTROLLER")
            distro = "sles"
          # compute or adt resource nodes
          elsif (serverInfo["role"].match("COMPUTE") or
                 serverInfo["role"].match("RESOURCE"))
            # check for blanket compute settings
            if sles_compute_all
              distro = "sles"
            elsif rhel_compute_all
              distro = "rhel"
            end
          end

          # check for specific node distro directives
          if ( sles_nodes.include? serverInfo["id"] )
            distro = "sles"
          elsif ( rhel_nodes.include? serverInfo["id"] )
            distro = "rhel"
          end

          # default to SLES if no distro selected
          if distro == ""
            distro = "sles"
          end

          serverInfo["os-dist"] = @distro_map[distro][:version]
        end
      end
      return metal_cfg
    end

    def set_sles(iso_files)
      return if not @ardana[:attach_isos]
      iso_files.push( get_image_output_dir() + "/#{@distro_map["sles"][:version]}.iso" )
      if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
        raise "Run 'ansible-playbook -i hosts/localhost get-ardana-artifacts.yml' to get the SLES ISOs"
      end
    end

    def set_sles_sdk(iso_files)
      return if not @ardana[:attach_isos]
      iso_files.push( get_image_output_dir() + "/#{@distro_map["sles"][:version]}sdk.iso" )
      if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
        raise "Run 'ansible-playbook -i hosts/localhost get-ardana-artifacts.yml' to get the SLES ISOs"
      end
    end

    def set_sles_cloud(iso_files)
      return if not @ardana[:attach_isos]
      iso_files.push( get_image_output_dir() + "/cloud#{@ardana[:cloud][:version]}.iso" )
      if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
        raise "Run 'ansible-playbook -i hosts/localhost get-ardana-artifacts.yml' to get the Cloud ISO"
      end
    end

    def set_rhel(iso_files)
      return if not @ardana[:attach_isos]
      iso_files.push( get_image_output_dir() + "/#{@distro_map["rhel"][:version]}.iso" )
      if !File.exists?(iso_files[-1]) and !ENV["ARDANA_CLEANUP_CI"]
        raise "Run 'ansible-playbook -i hosts/localhost get-ardana-artifacts.yml' to get the RHEL ISO"
      end
    end

    def setup_iso(server: None, name: None, distros: [distro])
      iso_files = []

      # add SLES & SOC ISOs
      set_sles(iso_files)
      set_sles_cloud(iso_files) if @ardana[:cloud][:artifacts]

      # RHEL
      if distros.any?{|d| d.include?("rhel")}
        set_rhel(iso_files)
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
      setup_vm(vm: server.vm, name: name, extra_vars: extra_vars, disks: disks)

      setup_iso(server: server, name: name, distros: distros)
    end
    private :provision_deployer

    def add_server_group(modifier: 0, cloud_name: None, deployer_node: None)
      metal_cfg = initialize_baremetal(cloud_name)
      server_details = metal_cfg["servers"]

      ip_offset = 1
      prev_node_type = ""

      distributions = server_details.map { |server| server["os-dist"] }.uniq

      server_details.each do |serverInfo|
        node_type = determine_node_type(serverInfo["role"])

        server_name = serverInfo["id"]
        box_name = serverInfo["os-dist"] + "box"

        @config.vm.define server_name do |server|
          set_vm_box(vm: server.vm, box: box_name)

          add_access_network(vm: server.vm)

          # Reserve a VIP address for each node type in Ardana
          if node_type != prev_node_type
            ip_offset += 1
            prev_node_type = node_type
          end

          add_ardana_network(vm: server.vm, ip: 1 + ip_offset + modifier)
          add_pxe_network(vm: server.vm, ip: serverInfo["ip-addr"], mac: serverInfo["mac-addr"])

          add_idle_networks(vm: server.vm, count: 6)

          set_vm_hardware(vm: server.vm, hardware: serverInfo['hardware'],
                          graphics_port: serverInfo["graphics_port"])

          # Add the requested number of disks for this node type
          disks = []
          hw_disks = serverInfo['hardware']['disks']
          if hw_disks.key?('extras')
            (1..hw_disks['extras']['count']).each do |i|
              disks.push({:bus => "scsi",
                          :size => hw_disks['extras']['size_gib'].to_i})
            end
          end

          # Provisioning VM
          extra_vars = {}
          if deployer_node == server_name
            provision_deployer(server: server,
                               name: server_name,
                               distros: distributions,
                               extra_vars: extra_vars,
                               disks: disks)
          else
            setup_vm(vm: server.vm, name: server_name,
                     extra_vars: {},
                     disks: disks)
          end

          ip_offset += 1
        end
      end
    end

    def setup_vm(vm: None, name: None, playbook: "vagrant-vm-setup", extra_vars: {}, disks: [])

      vm.provider :libvirt do |libvirt, override|
        disks.each do |disk|
          libvirt.storage :file, disk
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

      # If the vagrant-libvirt plugin has the "hack" implementing
      # serial device configuration, then setup # VM console logs
      # to redirect to specified file.
      vm.provider :libvirt do |libvirt, override|
        if libvirt.respond_to?('serial')  # if vagrant-libvirt hack present
          libvirt.serial :type => "file",
            :source => {
              :path => File.absolute_path(
                ( ENV['CONSOLE_LOG_DIR'] || "#{@dev_tool_path}/logs/console" ) + "/#{name}.log")
            }
        end
      end
    end

    def set_vm_box(vm: None, box: None)
      if openstack?
        vm.box = 'dummy'
        vm.box_url =
            'https://github.com/cloudbau/vagrant-openstack-plugin/raw/master/dummy.box'
      else
        vm.box = box

        # This sets the box for non-openstack vagrant configurations
        box_file = "#@dev_tool_path/#{box}.json"

        if File.exists?(box_file)
          box_json = File.read(box_file)
          box_json = JSON.parse(box_json)

          vm.box_url = "file://" + box_file
          vm.box_version = box_json["versions"][0]["version"]
        end
      end
    end

    def set_vm_hardware(vm: None, hardware: None, graphics_port: 5900)
      raise "No hardware specified" if !hardware

      vm.provider "virtualbox" do |vb, override|
        vb.memory = hardware['memory']
        vb.cpus = hardware['cpus']
      end

      vm.provider "libvirt" do |domain, override|
        domain.memory = hardware['memory']
        domain.cpus = hardware['cpus']
        domain.disk_bus = 'scsi'
        domain.volume_cache = 'unsafe'
        domain.nested = true
        domain.cpu_mode = 'host-passthrough'
        domain.machine_virtual_size = hardware['disks']['boot']['size_gib'].to_i
        domain.graphics_type = 'vnc'
        domain.graphics_port = graphics_port
      end

      vm.provider "openstack" do |os, override|
        os.flavor = /#{hardware['flavor']}/
      end
    end

    def add_access_network(vm: None)
      # Only add this is the provider in use is openstack - other providers already automatically
      # add a network for vagrant access
      if openstack?
        vm.network :public_network, type: 'dhcp'
      end
    end

    def get_ipv6_prefix(if_index)
      # Default randomly generated IPv6 ULAs
      ardana_ipv6_ula = []
      ula_file = "#@dev_tool_path/bin/default_ipv6_ula"
      if !File.exists?(ula_file)
        STDERR.puts "ERROR! Missing default_ula file: #{ula_file}"
      else
        ardana_ipv6_ula = File.read(ula_file).split(',').map(&:strip)
      end

      if !!ENV["ARDANA_NET_IPV6_ULA"]
        ardana_ipv6_ula_from_env = ENV["ARDANA_NET_IPV6_ULA"].split(',')
        if ardana_ipv6_ula_from_env.length < if_index.to_i
          return ardana_ipv6_ula[if_index.to_i]
        else
          return ardana_ipv6_ula_from_env[if_index.to_i]
        end
      else
        return ardana_ipv6_ula[if_index.to_i]
      end
    end

    def add_ip_opts(opts, if_index, ip_opts)
      [:v4, :v6].each do |s|
        if @ardana[:ip][s].include? if_index and ip_opts.include? s
          opts.merge!(ip_opts[s])
        end
      end

      STDERR.puts "if_index: #{if_index} opts: #{opts.inspect}" if @ardana[:debug]
    end

    def add_ardana_network(vm: None, ip: None, if_index: '1')
      opts = {
        libvirt__dhcp_enabled: false,
        auto_config: false,
      }

      ip_opts = {
        :v4 => {
          ip: "192.168.245.#{ip}",
          netmask: "255.255.255.0",
        },
        :v6 => {
          libvirt__guest_ipv6: "yes",
          libvirt__ipv6_address: get_ipv6_prefix(if_index),
          libvirt__ipv6_prefix: "64"
        }
      }

      add_ip_opts(opts, if_index, ip_opts)

      if !!ENV["ARDANA_ARDANA_INTF"]
        # Use the ARDANA_ARDANA_INTF interface in bridged mode
        opts[:dev] = ENV["ARDANA_ARDANA_INTF"]
        opts[:type] = "bridge"
        vm.network :public_network, opts
      else
        vm.network :private_network, opts
      end
    end

    def add_pxe_network(vm: None, ip: None, mac: None, if_index: '2')
      opts = {
        libvirt__dhcp_enabled: false,
        auto_config: true,
        mac: "#{mac}",
      }

      ip_opts = {
        :v4 => {
          ip: "#{ip}",
          netmask: "255.255.255.0",
        },
        :v6 => {
          libvirt__guest_ipv6: "yes",
          libvirt__ipv6_address: get_ipv6_prefix(if_index),
          libvirt__ipv6_prefix: "64"
        }
      }

      add_ip_opts(opts, if_index, ip_opts)

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
        if_index = (ip + 2).to_s

        opts = {
          libvirt__dhcp_enabled: false,
          auto_config: false,
        }

        ip_opts = {
          :v4 => {
            # even with auto_config:false, ip is required (using link local)
            ip: "169.254.#{ip}.2",
          },
          :v6 => {
            libvirt__guest_ipv6: "yes",
            libvirt__ipv6_address: get_ipv6_prefix(if_index),
            libvirt__ipv6_prefix: "64"
          }
        }

        add_ip_opts(opts, if_index, ip_opts)

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
          @config.ssh.username = ENV["ARDANAUSER"] ||= "ardana"
          @config.ssh.password = ENV["ARDANAUSER"] ||= "ardana"
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
