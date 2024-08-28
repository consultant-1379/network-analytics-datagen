#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Carp;
use lib '/eniq/home/dcuser/counters/lib';
use Encoding::BER;

my $usage = <<"USAGE";
 This script converts the given text file to ASN.1 format in the specified output directory.

 Usage:
        $0 <file> <output_dir>

    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 

 Example:
        $0 /eniq/home/dcuser/counters/test/input_data/eniq_oss_1/msc-iog/dir1/A19700101.0000-19700101.0015_msc_01 /eniq/data/pmdata/eniq_oss_1/msc-iog/dir1

USAGE

my $debug      = '';
my $help       = '';
my $verbose    = '';                                       # default is off

GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
);

if ($help) {
   print "$usage\n\n\n";
   exit 0;
}

# Save the input arguments
my $file       = $ARGV[0];
my $output_dir = $ARGV[1];

# Prepare the encoding object
my $enc = Encoding::BER->new();
add_tags($enc);    # add custom ASN.1 tags for PM counters

# Read in the text file
my $meas_data_collection = `/bin/cat $file`;

print "\nMeas_data_collection\n$meas_data_collection\n" if $debug;

# Create the output file name
my $basename = basename $file;
my $ne_file = "$output_dir/$basename";
print "File = '$ne_file'\n" if $verbose;

# Do the BER encoding (BER = Basic Encoding Rules)
my $ber = $enc->encode( eval "$meas_data_collection" ); 

# Dump the file to the output_dir
open my $NE_FH, '> :raw', "$ne_file" or croak "Cannot open file $ne_file, $!";
print {$NE_FH} $ber;
close $NE_FH or croak "Cannot close file $ne_file, $!";

exit 0;


#
#
# Subroutines
#
#


sub add_tags {
   my $enc = shift;
   $enc->add_implicit_tag( 'context', 'constructed', 'measFileHeader', 0, 'sequence' );
   $enc->add_implicit_tag( 'context', 'constructed', 'measData',       1, 'sequence' );
   $enc->add_implicit_tag( 'context', 'constructed', 'nEId',           0, 'sequence' );

   $enc->add_implicit_tag( 'context', 'primitive',   'measFileFooter', 2, 'octet_string' );
   $enc->add_implicit_tag( 'context', 'constructed', 'measInfo',       1, 'sequence' );

   $enc->add_implicit_tag( 'context', 'constructed', 'measTypes',  2, 'sequence' );
   $enc->add_implicit_tag( 'context', 'constructed', 'measValues', 3, 'sequence' );

   $enc->add_implicit_tag( 'context', 'primitive', 'fileFormatVersion',   0, 'integer' );
   $enc->add_implicit_tag( 'context', 'primitive', 'senderName',          1, 'octet_string' );
   $enc->add_implicit_tag( 'context', 'primitive', 'senderType',          2, 'octet_string' );
   $enc->add_implicit_tag( 'context', 'primitive', 'vendorName',          3, 'octet_string' );
   $enc->add_implicit_tag( 'context', 'primitive', 'collectionBeginTime', 4, 'octet_string' );

   $enc->add_implicit_tag( 'context', 'primitive', 'nEUserName',          0, 'octet_string' );
   $enc->add_implicit_tag( 'context', 'primitive', 'nEDistinguishedName', 1, 'octet_string' );

   $enc->add_implicit_tag( 'context', 'primitive', 'measTimeStamp',     0, 'octet_string' );
   $enc->add_implicit_tag( 'context', 'primitive', 'granularityPeriod', 1, 'integer' );

   $enc->add_implicit_tag( 'context', 'primitive', 'neValue',       0, 'integer' );
   $enc->add_implicit_tag( 'context', 'primitive', 'measObjInstId', 0, 'octet_string' );

   $enc->add_implicit_tag( 'context', 'constructed', 'measResults', 1, 'sequence' );

   $enc->add_implicit_tag( 'context', 'primitive', 'suspectFlag', 2, 'boolean' );

   return;
}


