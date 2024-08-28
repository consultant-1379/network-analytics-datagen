#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use Encoding::BER;
use Data::Dumper;
use Carp;
use Getopt::Long;
use YAML::Tiny qw(Dump LoadFile);
use ENIQ::DataGeneration;
use File::Path;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -f, --file
                dump measurement data to a text file
    -o <oss_id>, --oss_id=<oss_id>
                Identity of the OSS collecting the counter files
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 

 Example:
        $0 

 will create the ROP files for all counters in the input files.

 Example:
        $0 -s 2007-04-01 -e 2007-04-20 -r 20

 will create the ROP files for all counters in the input files, for the date range given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.

USAGE

my $debug      = '';
my $help       = '';
my $verbose    = '';                                       # default is off
my $time       = '';                                       # default is empty string, i.e. produce all 96 ROPs per day
my $file       = '';


GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
   'file'         => \$file,
);

if ($help) {
   print "$usage\n\n\n";
   exit;
}

set_debug() if $debug;

my ($node_type)          = $0 =~ m/generate_(\w+)_counter_files/; # extract node type from calling script name
my $root_dir             = '/eniq/home/dcuser/ManagedObjects';
my $node_counter_dir     = "/eniq/home/dcuser/counters/nodes/$node_type/Counters";
my @node_config_files    = get_configuration_info( root_dir         => $root_dir, node_type        => $node_type );
my %moids_for            =    get_managed_objects( root_dir         => $root_dir, node_counter_dir => $node_counter_dir );
my %counter_formulas_for =   get_counter_formulas( node_counter_dir => $node_counter_dir );

if ($debug) {
   print "node_config_for      :\n", Dump( \@node_config_files );
   print "moids_for            :\n", Dump( \%moids_for );
   print "\n";
}

for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config     = LoadFile( $node_config_file );
   my $bsc_id     = get_bsc_id($config->{associatedBsc});
   my $fdn        = "SubNetwork=$config->{ROOT_MO},SubNetwork=$bsc_id,MeContext=$node";
   my $output_dir = "/eniq/data/pmdata/$config->{OSS_ID}/$config->{OUTPUT_DIR}/dir1/";
   my %values_for;
   my $meas_data;
   my $meas_info;

   (my $file_date_time, $config->{cbt}, $config->{ts}, $config->{beginTime}, $config->{endTime} ) = get_time_info($config->{ROP_LENGTH}, $config->{timeZone});

   print "config :\n", Dump( $config ) if $debug;

   mkpath($output_dir);

   my $enc = Encoding::BER->new();
   add_tags($enc);    # add custom ASN.1 tags for PM counters

   $meas_info  .= meas_info_header();

   for my $mo_type (sort keys %moids_for) {
      my @node_mos = grep { /$fdn/ } @{ $moids_for{$mo_type} }; # find managed objects belonging to this node
      next unless @node_mos;                                    # skip if there are no managed objects with this MO type

      my $node_version   = $config->{nodeVersion};
      my $ne_mim_version = $config->{neMIMversion};

      debug("        mo_type : $mo_type");
      debug("   node_version : $node_version");
      debug(" ne_mim_version : $ne_mim_version");

      $config->{COUNTERS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{COUNTERS};
      $config->{FORMULAS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{FORMULAS};

      for my $moid (@node_mos) {
         debug("         moid:  $moid");

         eval "$config->{FORMULAS}"; # set measurement values in values_for hash

         # create a stringified version of an array of anonymous hashes containing measurement types
         my @meas_types = map { "{'type' => 'graphic_string', 'value' => '$_'}," } sort keys %values_for;

         # create a stringified version of an array of anonymous hashes containing measurement values
         my @meas_values = map { "{ 'type' => 'neValue', 'value' => $values_for{$_} }," } sort keys %values_for;

         if ($debug) {
            print "\nValues for $mo_type\n";
            print Dumper(%values_for);
            print "\nMeas_types\n";
            print "@meas_types";
            print Dumper(@meas_types);
            print "\nMeas_values\n";
            print "@meas_values";
            print Dumper(@meas_values);
         }

         my ($moi) = $moid =~ m/GeranCell=([^,]+),/;
         $meas_info  .= meas_info_body( $config->{cbt}, "$mo_type.$moi", "[@meas_types]", "[@meas_values]" );
         %values_for  = ();    # set hash to empty
      }
   }
   $meas_info .= meas_info_footer();

   $meas_data .= meas_data_header();
   $meas_data .= meas_data_start( $node, "Exchange Identity=$node,Object Type=$node") . $meas_info . meas_data_end();
   $meas_data .= meas_data_footer();

   my $meas_data_collection = meas_file_header( $node, $config->{managedElementType}, $config->{vendorName}, $config->{cbt} ) . $meas_data . meas_file_footer($config->{cbt});

   print "\nMeas_data_collection\n$meas_data_collection\n" if $debug;

   my $ber = $enc->encode( eval "$meas_data_collection" );
   my ($date, $start_time, $end_time) = $file_date_time =~ m/(\d+)\.(\d+)\+.*-(\d+)/;

   my $ne_file;
   if ( defined $ENV{OS} ) {    # If OS is defined the system is Windows, and it can't handle : (colon) in a filename.
      $ne_file = "$output_dir/A$date.$start_time-$date.${end_time}_${node}";    # DOS doesn't handle :1 in file names
   }
   else {
      $ne_file = "$output_dir/A$date.$start_time-$date.${end_time}_${node}:1";
   }

   # Save as text file or ASN.1 encoded depending on command line --file option, default is ASN.1
   if ($file) {
      open my $TEXT_FH, '>', "$ne_file" or croak "Cannot open file $ne_file, $!";
      print {$TEXT_FH} $meas_data_collection;
      close $TEXT_FH or croak "Cannot close file $ne_file, $!";
   } else {          
      open my $NE_FH, '> :raw', "$ne_file" or croak "Cannot open file $ne_file, $!";
      print {$NE_FH} $ber;
      close $NE_FH or croak "Cannot close file $ne_file, $!";
   }

}

exit 0;

#
# Subroutines
#
sub get_bsc_id {
   my $associatedBsc = shift;
   my ($bsc_id)      = $associatedBsc =~ m/=([^=]+)$/;
   return $bsc_id;
}

sub meas_file_header {
   my ( $ne_id, $node_type, $vendor, $collection_time ) = @_;
   return <<"MEASFILEHEADER"
[
    {
        type => 'measFileHeader',
        value => 
            [                  
                {
                    type  => 'fileFormatVersion',
                    value => 1
                },
                {
                    type  => 'senderName',
                    value => '$ne_id'
                },
                {
                    type  => 'senderType',
                    value => '$node_type'
                },
                {
                    type  => 'vendorName',
                    value => '$vendor'
                },
                {
                    type  => 'collectionBeginTime',
                    value => '$collection_time'
                },
            ]      
    },
MEASFILEHEADER
}

sub meas_file_footer {
   my ($start_time) = @_;
   return <<"MEASFILEFOOTER";
    {         
        type => 'measFileFooter',
        value => '$start_time'
    }
]
MEASFILEFOOTER
}

sub meas_data_header {
   return <<"MEASDATAHEADER";
    {         
        type => 'measData',
        value => 
            [ 
MEASDATAHEADER
}

sub meas_data_start {
   my ( $ne_user_name, $ne_distinguished_name ) = @_;
   return <<"MEASDATASTART";
                [
                    {
                        type => 'nEId',
                        value => 
                            [
                                {
                                    type  => 'nEUserName',
                                    value => '$ne_user_name'
                                },
                                { 
                                    type  => 'nEDistinguishedName',
                                    value => '$ne_distinguished_name'                   
                                }
                            ]
                    },
MEASDATASTART
}

sub meas_data_end {

   return <<'MEASDATAEND';
                ],
MEASDATAEND
}

sub meas_data_footer {

   return <<'MEASDATAFOOTER';
            ],
    },
MEASDATAFOOTER
}

sub meas_info_header {
   return <<'MEASINFOHEADER';
                    {
                        type => 'measInfo',
                        value => 
                            [
MEASINFOHEADER
}

sub meas_info_footer {
   return <<'MEASINFOFOOTER';
                            ],
                    },
MEASINFOFOOTER
}

sub meas_info_body {
   my ( $start_time, $object_type, $meas_types, $meas_values ) = @_;
   return <<"MEASINFO";
                              [
                                {
                                    type  => 'measTimeStamp',
                                    value => '$start_time'
                                },
                                { 
                                    type  => 'granularityPeriod',
                                    value => 900                  
                                },
                                {
                                     type => 'measTypes',
                                     value => $meas_types
                                },
                                {
                                     type => 'measValues',
                                     value => 
                                        [
                                          [
                                            {
                                                type  => 'measObjInstId',
                                                value => '$object_type'
                                            },
                                            {
                                                type  => 'measResults',
                                                value => $meas_values
                                            },
                                            {
                                                type  => 'suspectFlag',
                                                value => ''
                                            }
                                          ]
                                        ]                                      
                                },

                              ],
MEASINFO
}

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

