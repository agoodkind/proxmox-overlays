#!/usr/bin/env perl
use strict;
use warnings;
open(my $output, '>>', '/tmp/overlay-mail') or die $!;
while (my $line = <STDIN>) {
    print {$output} $line or die $!;
}
close($output) or die $!;
exit(-e '/tmp/overlay-mail-fail' ? 1 : 0);
