use strict;
use warnings;

use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;
use Test::More;

plan skip_all => 'Run only in a disposable container with PVE_OVERLAY_APT_TEST=1'
    if !$ENV{PVE_OVERLAY_APT_TEST};

my $root = tempdir(CLEANUP => 1);
make_path("$root/patches", '/usr/sbin');
copy("$FindBin::Bin/../pve-overlay", "$root/pve-overlay") or die $!;
chmod(0755, "$root/pve-overlay") or die $!;
copy("$FindBin::Bin/capture-mail.pl", '/usr/sbin/sendmail') or die $!;
chmod(0755, '/usr/sbin/sendmail') or die $!;

sub write_text {
    my ($path, $text) = @_;
    open(my $output, '>', $path) or die "$path: $!";
    print {$output} $text or die $!;
    close($output) or die $!;
}

sub read_text {
    my ($path) = @_;
    open(my $input, '<', $path) or die "$path: $!";
    local $/;
    return <$input>;
}

sub run {
    my (@command) = @_;
    # A file captures both streams without risking a full pipe during APT output.
    open(my $output, '>', "$root/output") or die $!;
    my $pid = fork() // die $!;
    if (!$pid) {
        open(STDOUT, '>&', $output) or die $!;
        open(STDERR, '>&', $output) or die $!;
        exec(@command);
        die "Cannot execute @command: $!";
    }
    waitpid($pid, 0);
    my $status = $? >> 8;
    close($output);
    return ($status, read_text("$root/output"));
}

sub build_package {
    my ($version, $contents) = @_;
    my $directory = "$root/package-$version";
    make_path("$directory/DEBIAN", "$directory/usr/share/perl5/PVE");
    my $control = <<"CONTROL";
Package: overlay-guard-fixture
Version: $version
Architecture: all
Maintainer: Test <test\@example.invalid>
Description: Overlay hook fixture
CONTROL
    write_text("$directory/DEBIAN/control", $control);
    write_text("$directory/usr/share/perl5/PVE/GuardFixture.pm", $contents)
        if defined($contents);
    my ($status, $output) = run('dpkg-deb', '--build', $directory, "$root/$version.deb");
    die $output if $status;
    return "$root/$version.deb";
}

my $original = build_package('1', "packaged\n");
my $conflicting = build_package('2', "changed upstream\n");
my $compatible = build_package('3', "packaged\n");
my $missing = build_package('4', undef);
my ($status, $output) = run('dpkg', '-i', $original);
is($status, 0, 'install the original fixture package') or diag($output);
my $fixture_patch = <<'PATCH';
diff --git a/PVE/GuardFixture.pm b/PVE/GuardFixture.pm
--- a/PVE/GuardFixture.pm
+++ b/PVE/GuardFixture.pm
@@ -1 +1 @@
-packaged
+overlay
PATCH
write_text("$root/patches/fixture.patch", $fixture_patch);
($status, $output) = run("$root/pve-overlay", 'apply');
is($status, 0, 'install the original overlay') or diag($output);
my $installed = read_text('/etc/perl/PVE/GuardFixture.pm');

($status, $output) = run('apt-get', 'install', '-y', $conflicting);
isnt($status, 0, 'APT rejects the conflicting archive');
like(
    $output,
    qr/fixture.patch: PVE\/GuardFixture.pm: the hunk at line 1/,
    'report the patch and failed hunk',
);
is(
    read_text('/usr/share/perl5/PVE/GuardFixture.pm'),
    "packaged\n",
    'APT leaves the package file intact',
);
is(read_text('/etc/perl/PVE/GuardFixture.pm'), $installed, 'APT leaves the overlay intact');
like(
    read_text('/tmp/overlay-mail'),
    qr/overlay-guard-fixture: 1 -> 2/,
    'mail contains the package versions',
);

write_text('/tmp/overlay-mail-fail', '');
($status, $output) = run('apt-get', 'install', '-y', $conflicting);
isnt($status, 0, 'mail failure does not permit the upgrade');
like($output, qr/sendmail rejected/, 'report the email failure');
unlink('/tmp/overlay-mail-fail') or die $!;

($status, $output) = run('apt-get', 'install', '-y', $missing);
isnt($status, 0, 'reject an upgrade that removes the patched module');
($status, $output) = run('apt-get', 'remove', '-y', 'overlay-guard-fixture');
isnt($status, 0, 'reject removal of the package that supplies the patched module');
($status, $output) = run('apt-get', 'install', '-y', $compatible);
is($status, 0, 'APT installs a compatible update') or diag($output);
($status, $output) = run('dpkg-query', '-W', '-f=${Version}', 'overlay-guard-fixture');
is($output, '3', 'dpkg records the compatible package version');
is(read_text('/etc/perl/PVE/GuardFixture.pm'), $installed,
    'post-install hook restores the overlay');
($status, $output) = run("$root/pve-overlay", 'remove');
is($status, 0, 'remove the installed overlay') or diag($output);
ok(!-e '/etc/apt/apt.conf.d/80pve-overlay', 'remove deletes the APT hook');
ok(!-e '/etc/dpkg/dpkg.cfg.d/pve-overlay', 'remove deletes the dpkg hook');
done_testing();
