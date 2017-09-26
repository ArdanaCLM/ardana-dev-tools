#
# (c) Copyright 2009-2014 https://github.com/fog/fog/blob/master/CONTRIBUTORS.md
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


require 'fog/libvirt/compute'
require 'fog/libvirt/models/compute/server'

require 'vagrant/util/subprocess'
require 'vagrant/util/which'

module Fog
  module Compute
    class Libvirt
      class Server
        # redefine address method to one that works for libvirt < 1.2.6

        # This retrieves the ip address of the mac address
        # It returns an array of public and private ip addresses
        # Currently only one ip address is returned, but in the future this could be multiple
        # if the server has multiple network interface
        alias_method :orig_addresses, :addresses
        def addresses(service_arg=service, options={})
          virsh_path = Vagrant::Util::Which.which('virsh')
          r = Vagrant::Util::Subprocess.execute(virsh_path, "version")
          version_regexp = Regexp.new("^Using API: QEMU \(.*\)$")
          match = version_regexp.match(r.stdout)
          if !match.nil?
            # if we have a match, we'll have a subgroup
            if Gem::Version.new(match[1]) <= Gem::Version.new('1.2.6')
              return compat_addresses(service_arg, options)
            end
          end

          # otherwise just call the original
          orig_addresses(service_arg, options)
        end

        def compat_addresses(service_arg=service, options={})
          mac=self.mac

          # Aug 24 17:34:41 juno arpwatch: new station 10.247.4.137 52:54:00:88:5a:0a eth0.4
          # Aug 24 17:37:19 juno arpwatch: changed ethernet address 10.247.4.137 52:54:00:27:33:00 (52:54:00:88:5a:0a) eth0.4
          # Check if another ip_command string was provided
          ip_command_global=service_arg.ip_command.nil? ? 'grep $mac /var/log/arpwatch.log|sed -e "s/new station//"|sed -e "s/changed ethernet address//g" |sed -e "s/reused old ethernet //" |tail -1 |cut -d ":" -f 4-| cut -d " " -f 3' : service_arg.ip_command
          ip_command_local=options[:ip_command].nil? ? ip_command_global : options[:ip_command]

          ip_command="mac=#{mac}; server_name=#{name}; "+ip_command_local

          ip_address=nil

          if service_arg.uri.ssh_enabled?

            # Retrieve the parts we need from the service to setup our ssh options
            user=service_arg.uri.user #could be nil
            host=service_arg.uri.host
            keyfile=service_arg.uri.keyfile
            port=service_arg.uri.port

            # Setup the options
            ssh_options={}
            ssh_options[:keys]=[ keyfile ] unless keyfile.nil?
            ssh_options[:port]=port unless keyfile.nil?
            ssh_options[:paranoid]=true if service_arg.uri.no_verify?

            begin
              result=Fog::SSH.new(host, user, ssh_options).run(ip_command)
            rescue Errno::ECONNREFUSED
              raise Fog::Errors::Error.new("Connection was refused to host #{host} to retrieve the ip_address for #{mac}")
            rescue Net::SSH::AuthenticationFailed
              raise Fog::Errors::Error.new("Error authenticating over ssh to host #{host} and user #{user}")
            end

            # Check for a clean exit code
            if result.first.status == 0
              ip_address=result.first.stdout.strip
            else
              # We got a failure executing the command
              raise Fog::Errors::Error.new("The command #{ip_command} failed to execute with a clean exit code")
            end

          else
            # It's not ssh enabled, so we assume it is
            if service_arg.uri.transport=="tls"
              raise Fog::Errors::Error.new("TlS remote transport is not currently supported, only ssh")
            end

            # Execute the ip_command locally
            # Initialize empty ip_address string
            ip_address=""

            IO.popen("#{ip_command}") do |p|
              p.each_line do |l|
                ip_address+=l
              end
              status=Process.waitpid2(p.pid)[1].exitstatus
              if status!=0
                raise Fog::Errors::Error.new("The command #{ip_command} failed to execute with a clean exit code")
              end
            end

            #Strip any new lines from the string
            ip_address=ip_address.chomp
          end

          # The Ip-address command has been run either local or remote now

          if ip_address==""
            #The grep didn't find an ip address result"
            ip_address=nil
          else
            # To be sure that the command didn't return another random string
            # We check if the result is an actual ip-address
            # otherwise we return nil
            unless ip_address=~/^(\d{1,3}\.){3}\d{1,3}$/
              raise Fog::Errors::Error.new(
                        "The result of #{ip_command} does not have valid ip-address format\n"+
                            "Result was: #{ip_address}\n"
                    )
            end
          end

          return { :public => [ip_address], :private => [ip_address]}
        end
      end
    end
  end
end
