#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;

# This script generates the documentation for any .pl files in the bin directory.
# Usage:
#        generate_documentation.pl
#
# No arguments needed.

my $dir = dirname($0);

#print "dir= $dir/..\n";

my $bin_dir = "$dir/../bin";
my $doc_dir = "$dir/../doc";
my (@files) = `ls $bin_dir`;

#print "@files\n";

@files = grep /\.pl/, @files;
s/\n//g for @files;
s/\.pl//g for @files;
#print "@files\n";


print "Generating documentation for:\n";

for my $file ( @files ) {
    print "   $file\n";
    `pod2html --noindex $bin_dir/$file.pl > $doc_dir/$file.html`;
}


