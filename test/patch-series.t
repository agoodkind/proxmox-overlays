use strict;
use warnings;

use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;
use Test::More tests => 5;

my $root = tempdir(CLEANUP => 1);
my $source = "$root/usr/share/perl5/PVE";
make_path($source, "$root/patches");
copy("$FindBin::Bin/../pve-overlay", "$root/pve-overlay") or die "cannot copy pve-overlay: $!";

sub write_text {
    my ($path, $content) = @_;
    open(my $handle, '>', $path) or die "cannot open $path: $!";
    print {$handle} $content;
    close($handle) or die "cannot write $path: $!";
}

sub read_text {
    my ($path) = @_;
    open(my $handle, '<', $path) or die "cannot open $path: $!";
    local $/;
    return <$handle>;
}

sub apply_patches {
    my ($target) = @_;
    open(
        my $handle,
        '-|',
        $^X,
        "$root/pve-overlay",
        'apply',
        '--no-system',
        '--source-root',
        $root,
        '--target-dir',
        $target,
        '--host-root',
        "$target/host",
    ) or die "cannot run pve-overlay: $!";
    my @output = <$handle>;
    close($handle);
    return $? >> 8;
}

sub edit_diff {
    my ($name, $hunk) = @_;
    return
        "diff --git a/PVE/$name.pm b/PVE/$name.pm\n"
        . "--- a/PVE/$name.pm\n+++ b/PVE/$name.pm\n"
        . $hunk;
}

sub create_added_diff {
    my ($line) = @_;
    return
        "diff --git a/PVE/Added.pm b/PVE/Added.pm\n"
        . "new file mode 100644\n--- /dev/null\n+++ b/PVE/Added.pm\n"
        . "@@ -0,0 +1 @@\n+$line\n";
}

write_text("$source/Existing.pm", "packaged\n");
write_text(
    "$root/patches/10.patch",
    edit_diff('Existing', "@@ -1 +1 @@\n-packaged\n+first edit\n") . create_added_diff('new file'),
);
write_text(
    "$root/patches/20.patch",
    edit_diff('Existing', "@@ -1 +0,0 @@\n-first edit\n")
        . edit_diff('Added', "@@ -1 +1 @@\n-new file\n+edited new file\n"),
);
write_text(
    "$root/patches/30.patch",
    edit_diff('Existing', "@@ -0,0 +1 @@\n+existing file after an empty result\n"),
);

my $target = "$root/target";
is(apply_patches($target), 0, 'the installer applies the patch series');
is(
    read_text("$target/PVE/Existing.pm"),
    "existing file after an empty result\n",
    'edits an existing module cumulatively',
);
is(
    read_text("$target/PVE/Added.pm"),
    "edited new file\n",
    'edits a module created by a previous patch',
);

write_text("$root/patches/40.patch", create_added_diff('duplicate creation'));
my $failed_target = "$root/failed";
is(apply_patches($failed_target), 1, 'rejects a second creation of the same module');
ok(!-e $failed_target, 'rejects the series before writing any files');
