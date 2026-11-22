#!/usr/bin/perl -T

use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON qw(decode_json);
use Scalar::Util qw(tainted);
use Test::More;
use PVE::File;
use PVE::SRIOV;

die "Run this test with perl -T.\n" if !${^TAINT};
$ENV{PATH} = '/usr/sbin:/usr/bin:/sbin:/bin';
my $root = tempdir(CLEANUP => 1);
my $address = '0000:00:00.1';
my $mac = '02:00:00:00:00:01';
my $desired = "$root/testpf.json";
PVE::File::file_set_contents(
    $desired,
    qq|{"numvfs":1,"vfs":[{"index":0,"mac":"$mac","driver":"vfio-pci"}]}|,
);
PVE::File::file_set_contents("$root/sriov_totalvfs", "1\n");
PVE::File::file_set_contents("$root/sriov_numvfs", "0\n");
symlink($root, "$root/virtfn0") or die "Cannot create the test VF: $!\n";

{
    no warnings 'redefine';
    local *PVE::SRIOV::pf_device = sub { return $root };
    local *PVE::SRIOV::saved = sub { return decode_json(PVE::File::file_get_contents($desired)) };
    local *PVE::SRIOV::run_command = sub {
        is_deeply($_[0], ['/usr/bin/udevadm', 'settle', '--timeout=10'], 'Settle resized VFs');
    };
    local *PVE::SRIOV::observe = sub {
        my (undef, $declaration) = @_;
        my $count = PVE::SRIOV::number("$root/sriov_numvfs");
        my $vf = { pci => $address, index => 0, mac => $mac, driver => 'vfio-pci' };
        return (
            {
                numvfs => $count,
                desired => $declaration,
                vfs => $count ? [$vf] : [],
            },
            {},
            {},
        );
    };
    my $state = PVE::SRIOV::update_port('testpf', undef, 'restore', {});
    is($state->{numvfs}, 1, 'Restore writes the saved count to an empty adapter');
    ok(!tainted($state->{desired}->{vfs}->[0]->{index}), 'Restore validates the saved VF index');
}

{
    no warnings 'redefine';
    my $net = "$root/net";
    make_path("$net/eth0");
    my $renames = 0;
    local *PVE::SRIOV::run_command = sub {
        my ($command) = @_;
        if ($command->[0] eq '/usr/bin/udevadm') {
            if ($renames == 1) {
                rename("$net/vfct", "$net/enp1s0v0") or die "Cannot apply the udev name: $!\n";
            }
            return;
        }
        my ($old, $new) = @$command[4, 6];
        rename("$net/$old", "$net/$new") or die "Cannot rename the VF: $!\n";
        $renames++;
    };
    PVE::SRIOV::settle_vf_interface($root, $address, 'vfct');
    ok(-d "$net/vfct", 'A late udev rename does not replace the declared VF name');
}

done_testing();
