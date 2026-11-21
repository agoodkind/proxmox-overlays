#!/usr/bin/perl

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Test::More;

# Use a temporary root to isolate the installed files and skip system service changes.
my $overlay_script = shift // die "Specify the repository or installed pve-overlay script.\n";
my $host_root = tempdir(CLEANUP => 1);
my @overlay_options = (
    '--no-system', '--host-root', $host_root, '--target-dir', "$host_root/etc/perl",
);

is(
    system($overlay_script, 'apply', @overlay_options),
    0,
    'Install the overlay against packaged Proxmox modules',
);
my @installed_paths = qw(
    etc/systemd/system/pve-overlay-sriov.service
    etc/systemd/system/pve-guests.service.d/50-pve-overlay-sriov.conf
    etc/systemd/system/pve-ha-lrm.service.d/50-pve-overlay-sriov.conf
    usr/share/pve-overlay/sriov-restore
    etc/perl/PVE/SRIOV.pm
    etc/perl/PVE/SRIOVLock.pm
    etc/perl/PVE/API2/SRIOV.pm
);
for my $path (@installed_paths) {
    ok(-f "$host_root/$path", "Installer wrote $path");
}
is(system($overlay_script, 'status', @overlay_options), 0,
    'Installed files match the distribution');

# A saved SR-IOV declaration still needs the service to restore virtual functions at boot.
my $declaration_directory = "$host_root/etc/pve-overlay/sriov";
make_path($declaration_directory);
my $declaration_path = "$declaration_directory/testpf.json";
open(my $declaration_file, '>', $declaration_path) or die "Cannot create $declaration_path: $!\n";
print {$declaration_file} qq|{"numvfs":1,"vfs":[]}\n|;
close($declaration_file) or die "Cannot write $declaration_path: $!\n";

is(
    system($overlay_script, 'remove', @overlay_options) >> 8,
    1,
    'A saved declaration prevents removal',
);
for my $path (@installed_paths) {
    ok(-f "$host_root/$path", "Rejected removal preserves $path");
}

unlink($declaration_path) or die "Cannot clear $declaration_path: $!\n";
is(
    system($overlay_script, 'remove', @overlay_options),
    0,
    'Remove the overlay after clearing the declaration',
);
for my $path (@installed_paths) {
    ok(!-e "$host_root/$path", "Installer removed $path");
}
done_testing();
