#!/usr/bin/perl

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Test::More;

my $script = shift // die "Specify the repository or installed pve-overlay script.\n";
my $root = tempdir(CLEANUP => 1);
my @options = ('--no-system', '--host-root', $root, '--target-dir', "$root/etc/perl");
is(system($script, 'apply', @options), 0, 'Install the overlay against packaged Proxmox modules');

my @paths = qw(
    etc/systemd/system/pve-overlay-sriov.service
    etc/systemd/system/pve-guests.service.d/50-pve-overlay-sriov.conf
    etc/systemd/system/pve-ha-lrm.service.d/50-pve-overlay-sriov.conf
    usr/share/pve-overlay/sriov-restore
    etc/perl/PVE/SRIOV.pm
    etc/perl/PVE/SRIOVLock.pm
    etc/perl/PVE/API2/SRIOV.pm
);
ok(-f "$root/$_", "Installer wrote $_") for @paths;
is(system($script, 'status', @options), 0, 'Installed files match the distribution');
make_path("$root/etc/pve-overlay/sriov");
my $saved = "$root/etc/pve-overlay/sriov/testpf.json";
open(my $state, '>', $saved) or die "Cannot create $saved: $!\n";
print {$state} qq|{"numvfs":1,"vfs":[]}\n|;
close($state) or die "Cannot write $saved: $!\n";
is(system($script, 'remove', @options) >> 8, 1, 'A saved declaration prevents removal');
ok(-f "$root/$_", "Rejected removal preserves $_") for @paths;
unlink($saved) or die "Cannot clear $saved: $!\n";
is(system($script, 'remove', @options), 0, 'Remove the overlay after clearing the declaration');
ok(!-e "$root/$_", "Installer removed $_") for @paths;
done_testing();
