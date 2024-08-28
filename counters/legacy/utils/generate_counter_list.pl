#!/usr/bin/perl
use strict;
use warnings;

# This script generates the list of counters used in the in the directory given as an argument.
# Usage:
#        generate_counter_list.pl <counter_dir>
#

my $dir = $ARGV[0];

my (@files) = `/bin/ls $dir`;

print "@files\n";

my %counters_for;

for my $file ( @files ) {
#    print "   $file\n";
    my ($object) = $file =~ m/(\w+)\./mx;

    chomp $file;
    my $file_path =  "$dir/$file";

    open(my $FH, '<', $file_path) or die "can't open $file_path: $!";
    while (<$FH>) {
       my ($counter) = m/^([A-Za-z]\w+)/mx;
       $counters_for{"$object:$counter"} = '' if $counter;

    }
    close($FH) or die "can't close $file_path: $!";
    
}

print "$_\n" for sort keys %counters_for;


