#!/usr/bin/env perl
use strict;
use warnings;

use Archive::Tar;
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON::PP;

my ($metadata, $fixture_dir) = @ARGV;
die "usage: $0 PINS_JSON FIXTURE_DIRECTORY\n" unless @ARGV == 2;
open(my $input, '<:raw', $metadata) or die "cannot open $metadata: $!\n";
my $pins = JSON::PP->new->decode(do { local $/; <$input> });
close($input);
die "provide a JSON object in $metadata\n" unless ref($pins) eq 'HASH';
my $destination = "$fixture_dir/installed-source";
die "$destination already exists\n" if -e $destination;
my $work = tempdir('installed-source-XXXXXXXX', DIR => $fixture_dir, CLEANUP => 1);

sub field {
    my ($case, $key, $pattern) = @_;
    die "provide an object for $case in $metadata\n" unless ref($pins->{$case}) eq 'HASH';
    my $value = $pins->{$case}->{$key};
    die "provide a valid $case.$key in $metadata\n"
        unless defined($value) && !ref($value) && $value =~ $pattern;
    return $value;
}

sub verify_file {
    my ($path, $expected) = @_;
    my $actual = Digest::SHA->new(256)->addfile($path)->hexdigest;
    die "$path has SHA-256 $actual, expected $expected\n" unless $actual eq $expected;
}

sub gh {
    system('gh', @_) == 0 or die "gh $_[0] $_[1] failed (wait status $?)\n";
}

sub download {
    my ($case, $repo, $asset_key, $digest_key) = @_;
    my $tag = field($case, 'release_tag', qr/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/);
    my $asset = field($case, $asset_key, qr/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/);
    my $sha = field($case, $digest_key, qr/\A[0-9a-f]{64}\z/);
    my $dir = "$work/$case";
    make_path($dir);
    gh('release', 'download', $tag, '--repo', $repo, '--pattern', $asset, '--dir', $dir);
    my $path = "$dir/$asset";
    verify_file($path, $sha);
    return $path;
}

my @cases = qw(installed-source-v1 installed-source-v2);
my @revisions = map { field($_, 'source_revision', qr/\A[0-9a-f]{40}\z/) } @cases;
die "both fixture pins must use the same Configs revision\n" unless $revisions[0] eq $revisions[1];
my $target = sha256_hex('suburban/hostartifact-acceptance');
for my $case (@cases) {
    my $asset = "hostconfig_fixture-$case-$target.tar.gz";
    field($case, 'asset', qr/\A\Q$asset\E\z/);
    field($case, 'bundle_asset', qr/\A\Q$asset\E\.sigstore\.json\z/);
}

my $program = 'configsctl';
field($program, 'asset', qr/\Aconfigsctl_linux_amd64\.tar\.gz\z/);
my $revision = field($program, 'source_revision', qr/\A[0-9a-f]{40}\z/);
my $signer = field($program, 'signer_revision', qr/\A[0-9a-f]{40}\z/);
my $member_digest = field($program, 'member_sha256', qr/\A[0-9a-f]{64}\z/);
my $tofu_version = field('tofu', 'release_tag', qr/\Av[0-9]+\.[0-9]+\.[0-9]+\z/);
$tofu_version =~ s/\Av//;
field('tofu', 'asset', qr/\Atofu_\Q$tofu_version\E_linux_amd64\.zip\z/);
my $tofu_digest = field('tofu', 'member_sha256', qr/\A[0-9a-f]{64}\z/);
for my $case (@cases) {
    download($case, 'agoodkind/configs', 'asset', 'sha256');
    download($case, 'agoodkind/configs', 'bundle_asset', 'bundle_sha256');
}
my $archive = download($program, 'agoodkind/configsctl', 'asset', 'sha256');
gh('attestation', 'verify', $archive, '--repo', 'agoodkind/configsctl',
    '--cert-identity', 'https://github.com/agoodkind/go-makefile/.github/workflows/_package.yml@refs/heads/main',
    '--source-ref', 'refs/heads/main', '--source-digest', $revision,
    '--signer-digest', $signer, '--deny-self-hosted-runners');
my $tar = Archive::Tar->new;
$tar->read($archive, 1) or die "cannot read $archive\n";
my $member = $tar->get_content($program) // die "the release lacks its $program executable\n";
die "$program executable differs from the pinned SHA-256\n" unless sha256_hex($member) eq $member_digest;
make_path("$work/bin");
open(my $output, '>:raw', "$work/bin/$program") or die "cannot create $program: $!\n";
print {$output} $member or die "cannot write $program: $!\n";
close($output) or die "cannot finish writing $program: $!\n";
my $tofu_archive = download('tofu', 'opentofu/opentofu', 'asset', 'sha256');
system('unzip', '-q', $tofu_archive, 'tofu', '-d', "$work/bin") == 0
    or die "cannot extract the OpenTofu executable (wait status $?)\n";
verify_file("$work/bin/tofu", $tofu_digest);
chmod(0755, "$work/bin/$program", "$work/bin/tofu") == 2 or die "cannot set executable modes: $!\n";
open(my $receipt, '>:raw', "$work/pins.json") or die "cannot create the verified pins: $!\n";
print {$receipt} JSON::PP->new->canonical->encode($pins) or die "cannot write the verified pins: $!\n";
close($receipt) or die "cannot finish writing the verified pins: $!\n";
rename($work, $destination) or die "cannot install fixtures in $destination: $!\n";
