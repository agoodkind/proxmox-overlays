#!/usr/bin/env perl

use strict;
use warnings;

use Archive::Tar;
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON::PP;

my ($pins_path, $fixture_directory) = @ARGV;
die "usage: $0 PINS_JSON FIXTURE_DIRECTORY\n" unless @ARGV == 2;
open(my $pins_file, '<:raw', $pins_path) or die "cannot open $pins_path: $!\n";
my $pins = JSON::PP->new->decode(do { local $/; <$pins_file> });
close($pins_file);
die "provide a JSON object in $pins_path\n" unless ref($pins) eq 'HASH';

# Stage files beside the destination. One rename installs the complete directory.
my $destination = "$fixture_directory/installed-source";
die "$destination already exists\n" if -e $destination;
my $staging_directory =
    tempdir('installed-source-XXXXXXXX', DIR => $fixture_directory, CLEANUP => 1);

sub pin_field {
    my ($pin_name, $field_name, $pattern) = @_;
    die "provide an object for $pin_name in $pins_path\n" unless ref($pins->{$pin_name}) eq 'HASH';
    my $value = $pins->{$pin_name}->{$field_name};
    die "provide a valid $pin_name.$field_name in $pins_path\n"
        unless defined($value) && !ref($value) && $value =~ $pattern;
    return $value;
}

sub verify_file_checksum {
    my ($path, $expected_checksum) = @_;
    my $actual_checksum = Digest::SHA->new(256)->addfile($path)->hexdigest;
    die "$path has SHA-256 $actual_checksum, expected $expected_checksum\n"
        unless $actual_checksum eq $expected_checksum;
}

sub run_gh {
    system('gh', @_) == 0 or die "gh $_[0] $_[1] failed (wait status $?)\n";
}

sub download_release_asset {
    my ($pin_name, $repository, $asset_field, $checksum_field) = @_;
    my $release_tag = pin_field($pin_name, 'release_tag', qr/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/);
    my $asset_name = pin_field($pin_name, $asset_field, qr/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/);
    my $checksum = pin_field($pin_name, $checksum_field, qr/\A[0-9a-f]{64}\z/);
    my $asset_directory = "$staging_directory/$pin_name";

    make_path($asset_directory);
    run_gh(
        'release',
        'download',
        $release_tag,
        '--repo',
        $repository,
        '--pattern',
        $asset_name,
        '--dir',
        $asset_directory,
    );
    my $asset_path = "$asset_directory/$asset_name";
    verify_file_checksum($asset_path, $checksum);
    return $asset_path;
}

# The acceptance test compares two fixture versions from the same Configs revision.
my @fixture_names = qw(installed-source-v1 installed-source-v2);
my @fixture_revisions =
    map { pin_field($_, 'source_revision', qr/\A[0-9a-f]{40}\z/) } @fixture_names;
die "both fixture pins must use the same Configs revision\n"
    unless $fixture_revisions[0] eq $fixture_revisions[1];

# Match each fixture archive and its Sigstore bundle to the acceptance target.
my $target_digest = sha256_hex('suburban/hostartifact-acceptance');
for my $fixture_name (@fixture_names) {
    my $archive_name = "hostconfig_fixture-$fixture_name-$target_digest.tar.gz";
    pin_field($fixture_name, 'asset', qr/\A\Q$archive_name\E\z/);
    pin_field($fixture_name, 'bundle_asset', qr/\A\Q$archive_name\E\.sigstore\.json\z/);
}

my $configsctl = 'configsctl';
pin_field($configsctl, 'asset', qr/\Aconfigsctl_linux_amd64\.tar\.gz\z/);
my $configsctl_revision = pin_field($configsctl, 'source_revision', qr/\A[0-9a-f]{40}\z/);
my $signer_revision = pin_field($configsctl, 'signer_revision', qr/\A[0-9a-f]{40}\z/);
my $configsctl_checksum = pin_field($configsctl, 'member_sha256', qr/\A[0-9a-f]{64}\z/);

my $tofu_version = pin_field('tofu', 'release_tag', qr/\Av[0-9]+\.[0-9]+\.[0-9]+\z/);
$tofu_version =~ s/\Av//;
pin_field('tofu', 'asset', qr/\Atofu_\Q$tofu_version\E_linux_amd64\.zip\z/);
my $tofu_checksum = pin_field('tofu', 'member_sha256', qr/\A[0-9a-f]{64}\z/);

# Check the pinned bytes of each fixture archive and its Sigstore bundle.
for my $fixture_name (@fixture_names) {
    download_release_asset($fixture_name, 'agoodkind/configs', 'asset', 'sha256');
    download_release_asset($fixture_name, 'agoodkind/configs', 'bundle_asset', 'bundle_sha256');
}

# The checksum matches the archive to the pin. GitHub's attestation check verifies the
# workflow identity and the pinned source and signer revisions.
my $configsctl_archive =
    download_release_asset($configsctl, 'agoodkind/configsctl', 'asset', 'sha256');
run_gh(
    'attestation',
    'verify',
    $configsctl_archive,
    '--repo',
    'agoodkind/configsctl',
    '--cert-identity',
    'https://github.com/agoodkind/go-makefile/.github/workflows/_package.yml@refs/heads/main',
    '--source-ref',
    'refs/heads/main',
    '--source-digest',
    $configsctl_revision,
    '--signer-digest',
    $signer_revision,
    '--deny-self-hosted-runners',
);

# Extract only the executable from each archive and check its own pinned checksum.
my $tar = Archive::Tar->new;
$tar->read($configsctl_archive, 1) or die "cannot read $configsctl_archive\n";
my $configsctl_contents = $tar->get_content($configsctl)
    // die "the release lacks its $configsctl executable\n";
die "$configsctl executable differs from the pinned SHA-256\n"
    unless sha256_hex($configsctl_contents) eq $configsctl_checksum;

my $bin_directory = "$staging_directory/bin";
make_path($bin_directory);
open(my $configsctl_file, '>:raw', "$bin_directory/$configsctl")
    or die "cannot create $configsctl: $!\n";
print {$configsctl_file} $configsctl_contents or die "cannot write $configsctl: $!\n";
close($configsctl_file) or die "cannot finish writing $configsctl: $!\n";

my $tofu_archive = download_release_asset('tofu', 'opentofu/opentofu', 'asset', 'sha256');
system('unzip', '-q', $tofu_archive, 'tofu', '-d', $bin_directory) == 0
    or die "cannot extract the OpenTofu executable (wait status $?)\n";
verify_file_checksum("$bin_directory/tofu", $tofu_checksum);

chmod(0755, "$bin_directory/$configsctl", "$bin_directory/tofu") == 2
    or die "cannot set executable modes: $!\n";
open(my $verified_pins_file, '>:raw', "$staging_directory/pins.json")
    or die "cannot create the verified pins: $!\n";
print {$verified_pins_file} JSON::PP->new->canonical->encode($pins)
    or die "cannot write the verified pins: $!\n";
close($verified_pins_file) or die "cannot finish writing the verified pins: $!\n";
rename($staging_directory, $destination) or die "cannot install fixtures in $destination: $!\n";
