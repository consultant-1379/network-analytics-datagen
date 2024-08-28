#!/usr/bin/perl
use strict;
use warnings;

my $NUM_BINS          = 100;
my $MAX_VALUE         = 100000;
my @normal_dist_shape = get_normal_dist_shape();

print sprintf "pmRadioRecInterferencePwrBrPrb%d = int ( rand(%d) )\n", $_, int(rand($MAX_VALUE * $normal_dist_shape[$_])) for (1..$NUM_BINS);

exit 0;

#
# Subroutines
#

sub get_normal_dist_shape {
return qw(
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
1
2
0
0
0
0
3
1
1
2
6
2
5
4
12
11
7
9
11
17
21
13
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
6
7
8
3
2
3
0
1
0
0
1
0
1
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
0
);
}
