#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy for SGSN MMEs in a Core network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# An SGSN MME is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/ManagedElement=sgsn_mme_01
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

my $root_mo  = 'ONRM_RootMo';
my $root_dir = '/eniq/home/dcuser/ManagedObjects';

my @config_sections       = qw(ATTRIBUTES METADATA);
my $config_sections_match = "@config_sections";  # create a regex match pattern
$config_sections_match    =~ s/ /|/g;

# Remove old paths they exist and if --clean argument given
clean_old_paths(root_dir => $root_dir, node_prefix => 'ManagedElement\=sgsn_mme_') if -d $root_dir and $clean;

my %node_model = (
   # These DEFAULT attributes are the CONFIGURATIONs for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ATTRIBUTES                => {
         daylightSavingsAdjust     => 1,
         fileFormatVersion         => '32.435 V8.0',
         managedElementType        => 'SGSN,MME',
         neMIMversion              => '14.2.5',
         nodeVersion               => '16B',
         siteRef                   => '200000',
         swVersion                 => 'CXP102051/21_R38ES',
         timeZone                  => '+0100',
         vendorName                => 'Ericsson',
         worldTimeZoneId           => 'Europe/Dublin',
      },
      METADATA                 => {
         GENERATION                => 'G2',
         OSS_ID                    => 'eniq_oss_1',
         OUTPUT_DIR                => 'sgsn_mme_cba',
         PREFIX                    => 'sgsn_mme_',
         QOS_CLASSES               => [1, 5, 9],
         REPORTING                 => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                  => $root_dir,
         ROOT_MO                   => $root_mo,
         ROP_LENGTH                => 900,
         SUBNETWORK                => 'EPC',
         TOPOLOGY_DIR              => 'core/topologyData/CoreNetwork',
      },
   },
   Group_1 => {
      # These CONFIGURATION attributes are the overridden local versions
     Instances                => [1..5, 20],      
   },
   Group_2 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.6',
         },
         METADATA                 => {
            QOS_CLASSES               => [1 .. 9],
         },
      },
      Instances                => [6],      
   },
   Group_3 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.7',
         },
      },
      Instances                => [7],      
   },
   Group_4 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.8',
         },
      },
      Instances                => [8],      
   },
   Group_5 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.9',
         },
         METADATA                 => {
            QOS_CLASSES               => [1, 2, 3, 5, 9],
         },
      },
      Instances                => [9],      
   },
   Group_6 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.10',
         },
         METADATA                 => {
            QOS_CLASSES               => [1, 5, 8, 9],
         },
      },
      Instances                => [10],      
   },
   Group_7 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.11',
         },
         METADATA                 => {
            QOS_CLASSES               => [5, 8, 9],
         },
      },
      Instances                => [11],
   },
   Group_8 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.12',
         },
         METADATA                 => {
            QOS_CLASSES               => [1, 3, 4, 5, 8, 9],
         },
      },
      Instances                => [12],
   },
);

#print "node_model :\n", YAML::Tiny::Dump( \%node_model ) if $debug;


for my $grouping (sort keys %node_model) {
   next if $grouping eq 'CONFIGURATION';
   #   my %parameters = %{ $node_model{CONFIGURATION} };                                        # set default values
   my %parameters = %{ dclone($node_model{CONFIGURATION}) };                                        # set default values
   
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

   my $node_dir  = "$root_dir/SubNetwork=$parameters{METADATA}{ROOT_MO}/SubNetwork=$parameters{METADATA}{SUBNETWORK}/ManagedElement=$node_id"; 
   my $node_file = "$node_dir/$node_id.conf";
   print "node_dir  = $node_dir\n" if $debug;
   print "node_file = $node_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   my %file_parameters;
   $file_parameters{$_} = $parameters{$_} for (@config_sections);
   # Create the configuration file for each node
   my $yaml = YAML::Tiny->new( \%file_parameters );
   $yaml->write( $node_file );

   print "  Model :\n", YAML::Tiny::Dump( \%{ $parameters{ManagedElement} } ) if $debug;

   # SgsnFunction MOs
   my $sgsn_dir = "$node_dir/SgsnFunction=1";
   mkpath($sgsn_dir) unless -d $sgsn_dir;

    # SgsnMme MOs
   my $sgsn_mme_dir = "$node_dir/SgsnMme=1";
   mkpath($sgsn_mme_dir) unless -d $sgsn_mme_dir;

   # QosClassIdentifier MOs
   for my $QosClassIdentifier (@{ $parameters{METADATA}{QOS_CLASSES} } ) {
      print "            QosClassIdentifier             = $QosClassIdentifier\n" if $debug;
      my $dir = "$sgsn_mme_dir/QosClassIdentifier=$QosClassIdentifier";
      mkpath($dir) unless -d $dir;
   }
 

}

