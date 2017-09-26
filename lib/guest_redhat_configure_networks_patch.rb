#
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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
# Patch guest RedHat configure networks behaviour for rhel7 machines
require Vagrant.source_root.join('plugins/guests/redhat/cap/configure_networks.rb').to_s

module VagrantPlugins
  module GuestRedHat
    module Cap
      class ConfigureNetworks
        def self.configure_networks_rhel7(machine, networks)
          network_scripts_dir = machine.guest.capability("network_scripts_dir")

          virtual = false
          interface_names = Array.new
          machine.communicate.sudo("/usr/sbin/biosdevname; echo $?") do |_, result|
            virtual = true if result.chomp == '4'
          end

          if virtual
            machine.communicate.sudo("ls /sys/class/net | grep -v lo") do |_, result|
              interface_names = result.split("\n")
            end
          else
            machine.communicate.sudo("/usr/sbin/biosdevname -d | grep Kernel | cut -f2 -d: | sed -e 's/ //;'") do |_, result|
              interface_names = result.split("\n")
            end

            interface_name_pairs = Array.new
            interface_names.each do |interface_name|
              machine.communicate.sudo("/usr/sbin/biosdevname --policy=all_ethN -i #{interface_name}") do |_, result|
                interface_name_pairs.push([interface_name, result.gsub("\n", "")])
              end
            end

            setting_interface_names = networks.map do |network|
               "eth#{network[:interface]}"
            end

            interface_name_pairs.each do |interface_name, previous_interface_name|
              if setting_interface_names.index(previous_interface_name) == nil
                interface_names.delete(interface_name)
              end
            end
          end

          # Accumulate the configurations to add to the interfaces file as well
          # as what interfaces we're actually configuring since we use that later.
          interfaces = Set.new
          networks.each do |network|
            interface = interface_names[network[:interface]]
            interfaces.add(interface)
            network[:device] = interface

            # Remove any previous vagrant configuration in this network
            # interface's configuration files.
            machine.communicate.sudo("touch #{network_scripts_dir}/ifcfg-#{interface}")
            machine.communicate.sudo("sed -e '/^#VAGRANT-BEGIN/,/^#VAGRANT-END/ d' #{network_scripts_dir}/ifcfg-#{interface} > /tmp/vagrant-ifcfg-#{interface}")
            machine.communicate.sudo("cat /tmp/vagrant-ifcfg-#{interface} > #{network_scripts_dir}/ifcfg-#{interface}")
            machine.communicate.sudo("rm -f /tmp/vagrant-ifcfg-#{interface}")

            # Render and upload the network entry file to a deterministic
            # temporary location.
            entry = TemplateRenderer.render("guests/fedora/network_#{network[:type]}",
                                            options: network)

            temp = Tempfile.new("vagrant")
            temp.binmode
            temp.write(entry)
            temp.close

            machine.communicate.upload(temp.path, "/tmp/vagrant-network-entry_#{interface}")
          end

          # Bring down all the interfaces we're reconfiguring. By bringing down
          # each specifically, we avoid reconfiguring p7p (the NAT interface) so
          # SSH never dies.
          interfaces.each do |interface|
            machine.communicate.sudo("cat /tmp/vagrant-network-entry_#{interface} >> #{network_scripts_dir}/ifcfg-#{interface}")
            retryable(on: Vagrant::Errors::VagrantError, tries: 3, sleep: 2) do
              machine.communicate.sudo("/sbin/ifdown #{interface}", error_check: true)
              machine.communicate.sudo("/sbin/ifup #{interface}")
            end

            machine.communicate.sudo("rm -f /tmp/vagrant-network-entry_#{interface}")
          end
        end
      end
    end
  end
end


