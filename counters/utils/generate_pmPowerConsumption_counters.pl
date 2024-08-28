#!/usr/bin/perl
use strict;
use warnings;

my $NUM_BINS       = 150;
my $MAX_VALUE      = 40; # 40 Watts is equivalent to 46dBm
my $sprintf_string = "%d," x $NUM_BINS;
chop $sprintf_string;

my $rand_string;
$rand_string .= sprintf ",pmPowerConsumption()" for (1..$NUM_BINS);

print "pmPowerConsumption = sprintf '$sprintf_string'$rand_string\n";

