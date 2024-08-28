#!/usr/bin/perl
use strict;
use warnings;

my $NUM_BINS          = 31;
my $MAX_VALUE         = 10;
my @normal_dist_shape = get_normal_dist_shape();

#print "@normal_dist_shape\n";
my $sprintf_string = "%d," x $NUM_BINS;
chop $sprintf_string;

my $rand_string;

$rand_string .= sprintf ",rand(%d)", int(rand($MAX_VALUE)*$normal_dist_shape[$_]) for (0 .. 30);

print "pmSamplesSumAckedBitsRlim = sprintf '$sprintf_string'$rand_string\n";

exit 0;

#
# Subroutines
#

sub get_normal_dist_shape {
return qw(
23
33
24
32
30
27
36
38
39
37
47
34
43
26
55
38
36
37
32
19
23
19
16
17
24
11
13
9
7
9
6
3
);
}
