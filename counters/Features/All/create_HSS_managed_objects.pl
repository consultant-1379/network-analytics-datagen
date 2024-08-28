#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy for HSSs in a Core network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# An HSS is represented by
#    DC=ims.ericsson.com,g3SubNetwork=IMS,g3ManagedElement=hss_10
#
#[TODO] Fix this whole description
#
#
# 
# Call the script with a -c argument to start with a new model structure.
# Note that all accumulated counters with history will be reset if -c is used.
#
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::DataGeneration;
use YAML::Tiny;
use File::Path;
use Carp;
use Getopt::Long;
use Storable qw(dclone);

my $usage = <<"USAGE";
 This script creates a Managed Object Model file structure for a Network Analytics Server test model.

 Usage:
        $0 [options]

    -c, --clean
                clean the old directories (if any)
    -d, --debug
                output debug information
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information

 Example:
        $0 

 will create the Managed Object Model.

USAGE

my $clean      	= '';
my $debug      	= '';
my $help       	= '';
my $verbose    	= ''; # default is off

GetOptions(
   'clean'        => \$clean,
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
);

if ($help) {
   print "$usage\n\n\n";
   exit;
}

my $root_dir                = '/eniq/home/dcuser/ManagedObjects';

my $g3SubNetwork            = 'g3SubNetwork';
my $g3ManagedElement_prefix = 'hss_';

my @config_sections       = qw(ATTRIBUTES METADATA);
my $config_sections_match = "@config_sections";  # create a regex match pattern
$config_sections_match    =~ s/ /|/g;

# Remove old paths they exist and if --clean argument given
#clean_old_paths(root_dir => $root_dir, node_prefix => "DC\=$root_mo,g3SubNetwork\=$g3SubNetwork,g3ManagedElement\=$g3ManagedElement_prefix") if -d $root_dir and $clean;


# Need to replace = in processor name with double underscore to simplify instance handling.
# It will be substitued back in the counter file
my @processors = (
   'PlatformMeasures__DEFAULT,Source__Proc_m0_s1',
   'PlatformMeasures__DEFAULT,Source__Proc_m0_s13',
   'PlatformMeasures__DEFAULT,Source__Proc_m0_s15',
   'PlatformMeasures__DEFAULT,Source__Proc_m0_s3',
   'PlatformMeasures__DEFAULT,Source__Proc_m0_s5',
   'PlatformMeasures__DEFAULT,Source__Proc_m0_s7',
   'PlatformMeasures__DEFAULT,Source___SYSTEM',
   'PlatformMeasures__DEFAULT,Source__io1',
   'PlatformMeasures__DEFAULT,Source__io2',
);

my @vprocessors = (
   'LemService__OSMonitor,OsmPU__PL-10',
   'LemService__OSMonitor,OsmPU__PL-11',
   'LemService__OSMonitor,OsmPU__PL-12',
   'LemService__OSMonitor,OsmPU__PL-13',
   'LemService__OSMonitor,OsmPU__PL-14',
   'LemService__OSMonitor,OsmPU__PL-15',
   'LemService__OSMonitor,OsmPU__PL-16',
   'LemService__OSMonitor,OsmPU__PL-17',
   'LemService__OSMonitor,OsmPU__PL-18',
   'LemService__OSMonitor,OsmPU__PL-3',
   'LemService__OSMonitor,OsmPU__PL-4',
   'LemService__OSMonitor,OsmPU__PL-5',
   'LemService__OSMonitor,OsmPU__PL-6',
   'LemService__OSMonitor,OsmPU__PL-7',
   'LemService__OSMonitor,OsmPU__PL-8',
   'LemService__OSMonitor,OsmPU__PL-9',
);


my %node_model = (
   # These DEFAULT attributes are the CONFIGURATIONs for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ATTRIBUTES                => {
         daylightSavingsAdjust     => 1,
         fileFormatVersion         => '32.401 V5.0',
         managedElementType        => 'HSS',
         neMIMversion              => '14.2.5',
         nodeVersion               => '15A',
         siteRef                   => '200000',
         sourceType                => 'TSP',
         swVersion                 => 'CXP102051/21_R38ES',
         timeZone                  => '+0100',
         vendorName                => 'Ericsson',
         worldTimeZoneId           => 'Europe/Dublin',
      },
      METADATA                 => {
         FDN_FORMAT                 => 'SubNetwork=%s/SubNetwork=%s/MeContext=%s',
         GENERATION                 => 'G1',
         OSS_ID                     => 'eniq_oss_1',
         OUTPUT_DIR                 => 'hss',
         PREFIX                     => $g3ManagedElement_prefix,
         REPORTING                  => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                   => $root_dir,
         ROOT_MO                    => 'ONRM_RootMo',
         ROP_LENGTH                 => 900,
         PLATFORM                   => 'TSP',
         PeerNodes                  => ['ims1.ericsson.com', 'ims2.ericsson.com', 'ims3.ericsson.com' ],
         Processors                 => \@processors,
         SUBNETWORK                 => 'UM',
         TOPOLOGY_DIR               => 'core/topologyData/CoreNetwork',
      },
   },
   Group_1 => {
      # These CONFIGURATION attributes are the overridden local versions
      Instances                => [],
   },
   Group_2 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            nodeVersion               => '16A',
            neMIMversion              => '15.3.6',
         },
      },
      Instances                => [],
   },
   Group_3 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            nodeVersion               => '17A',
            neMIMversion              => '17.4.7',
         },
      },
      Instances                => [],
   },
   Group_vHSS_1 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            fileFormatVersion         => '32.435 V10.0',
            managedElementType        => 'HSS-FE,Vinfra',
            nodeVersion               => '1.13',
            neMIMversion              => '18.1.1',
            sourceType                => 'CBA',
            swVersion                 => 'CXP9035082/6 1.13.0-14',
         },
         METADATA                  => {
            FDN_FORMAT                 => 'SubNetwork=%s/SubNetwork=%s/MeContext=%s',
            GENERATION                 => 'G2',
            OUTPUT_DIR                 => 'HSS_CBA',
            PeerNodes                  => ['ims10.ericsson.com', 'ims12.ericsson.com', 'ims13.ericsson.com' ],
            PLATFORM                   => 'CBA',
            Processors                 => \@vprocessors,
            ROP_LENGTH                 => 900,
          },
      },
      Instances                => [10 .. 15, 20],
   },
   Group_vHSS_2 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            fileFormatVersion         => '32.435 V10.0',
            managedElementType        => 'HSS-FE,Vinfra',
            nodeVersion               => '1.2',
            neMIMversion              => '18.2.1',
            sourceType                => 'CBA',
            swVersion                 => 'CXP9020355_2 R5B03',
         },
         METADATA                  => {
            FDN_FORMAT                 => 'SubNetwork=%s/SubNetwork=%s/MeContext=%s',
            GENERATION                 => 'G2',
            OUTPUT_DIR                 => 'HSS_CBA',
            PeerNodes                  => ['ims10.ericsson.com', 'ims12.ericsson.com', 'ims13.ericsson.com' ],
            PLATFORM                   => 'CBA',
            Processors                 => \@vprocessors,
            ROP_LENGTH                 => 900,
          },
      },
      Instances                => [21 .. 22],
   },
   Group_vHSS_3 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            fileFormatVersion         => '32.435 V10.0',
            managedElementType        => 'HSS-FE,Vinfra',
            nodeVersion               => '1.8',
            neMIMversion              => '18.8.1',
            sourceType                => 'CBA',
            swVersion                 => 'CXP9020355_2 R5B04',
         },
         METADATA                  => {
            FDN_FORMAT                 => 'SubNetwork=%s/SubNetwork=%s/MeContext=%s',
            GENERATION                 => 'G2',
            OUTPUT_DIR                 => 'HSS_CBA',
            PeerNodes                  => ['ims10.ericsson.com', 'ims12.ericsson.com', 'ims13.ericsson.com' ],
            PLATFORM                   => 'CBA',
            Processors                 => \@vprocessors,
            ROOT_MO                    => 'ONRM_RootMo',
            ROP_LENGTH                 => 900,
            SUBNETWORK                 => 'UM',
          },
      },
      Instances                => [23 .. 24],
   },
);



#print "node_model :\n", YAML::Tiny::Dump( \%node_model ) if $debug;


for my $grouping (sort keys %node_model) {
   next if $grouping eq 'CONFIGURATION';
   my %parameters = %{ dclone($node_model{CONFIGURATION}) }; # set default values
   
   for my $config (keys %{ $node_model{$grouping}{CONFIGURATION} }) {
      next if $config =~ m/$config_sections_match/;
      $parameters{CONFIGURATION}{$config} = $node_model{$grouping}{CONFIGURATION}{$config}; # override with local grouping parameters
   }

   for my $config_section (@config_sections) {
      $parameters{$config_section}{$_} = $node_model{$grouping}{CONFIGURATION}{$config_section}{$_} for keys %{ $node_model{$grouping}{CONFIGURATION}{$config_section} }; # override with local grouping parameters
   }

   for my $node_index (@{ $node_model{$grouping}{Instances} } ) {
      create_managed_objects($node_index, %parameters);
   }
}

exit 0;

#
# Subroutines
#
#
sub create_managed_objects {
   my ($node_index, %parameters) = @_;

   my $node_id = sprintf "$parameters{METADATA}{PREFIX}%02d", $node_index;
   print "node_id             = $node_id\n" if $debug;
   print "  parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   my $node_dir  = sprintf "$root_dir/$parameters{METADATA}{FDN_FORMAT}", $parameters{METADATA}{ROOT_MO}, $parameters{METADATA}{SUBNETWORK}, $node_id; 
   my $node_file = "$node_dir/$node_id.conf";
   print "node_dir  = $node_dir\n" if $debug;
   print "node_file = $node_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   my $default_dir = "$node_dir/DEFAULT=DEFAULT";
   mkpath($default_dir) unless -d $default_dir;

   my %file_parameters;
   $file_parameters{$_} = $parameters{$_} for (@config_sections);

   # Create the configuration file for each node
   my $yaml = YAML::Tiny->new( \%file_parameters );
   $yaml->write( $node_file );

   print "  Model :\n", YAML::Tiny::Dump( \%{ $parameters{ManagedElement} } ) if $debug;

   # PeerNode MOs
   for my $PeerNode (@{ $parameters{METADATA}{PeerNodes} } ) {
      print "            PeerNode             = $PeerNode\n" if $debug;
      my $PeerNode_dir = "$node_dir/PeerNode=$PeerNode";
      mkpath($PeerNode_dir) unless -d $PeerNode_dir;
   }

   # Processor MOs
   for my $Processor (@{ $parameters{METADATA}{Processors} } ) {
      print "            Processor             = $Processor\n" if $debug;
      my $Processor_dir = "$node_dir/Processor=$Processor";
      mkpath($Processor_dir) unless -d $Processor_dir;
   }

}

