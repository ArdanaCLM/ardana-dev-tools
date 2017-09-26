This element clears out /etc/resolv.conf and prevents dhclient from populating
it with data from DHCP. This means that DNS resolution will not work from the
amphora. This is OK because all outbound connections from the amphora will
be based using raw IP addresses.

This has the real benefit of speeding up host boot and configutation times.
This is especially helpful when running tempest tests in a devstack environment
where DNS resolution from the amphora usually doesn't work anyway: This means
that the amphora never waits for DNS timeouts to occur.
