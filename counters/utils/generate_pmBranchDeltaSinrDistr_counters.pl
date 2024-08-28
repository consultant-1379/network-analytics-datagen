#!/usr/bin/perl
use strict;
use warnings;
use List::Util qw(shuffle);

my $MAX_BINS  = 60;
my $MAX_VALUE = 100;

my $debug = 0;

# pmBranchDeltaSinrDistr0 = sprintf '10,0,%d,1,%d,2,%d,3,%d,4,%d,5,%d,6,%d,7,%d,8,%d,9,%d', rand(20), rand(10), rand(5), rand(5), rand(50), rand(5), rand(5), rand(5), rand(5), rand(5)

for my $branch (0 .. 6) {
   my $bins = int(rand($MAX_BINS));
   my @all_bins = (0 .. $MAX_BINS);
   my @selected_bins = (shuffle @all_bins)[0 .. $bins];
   @selected_bins = sort {$a <=> $b} @selected_bins;

   my $selected_bins_count = $#selected_bins + 1; # add one to offset count from zero

   $" = ',%d,';  # set LIST_SEPARATOR
   my $sprintf_string = "'$selected_bins_count,@selected_bins,%d'";

   my $rand_string;
   $rand_string .= sprintf ",rand(%d)+1", int(rand($MAX_VALUE)+1) for @selected_bins;
   
   my $counter = "pmBranchDeltaSinrDistr$branch = sprintf $sprintf_string$rand_string\n";
}
