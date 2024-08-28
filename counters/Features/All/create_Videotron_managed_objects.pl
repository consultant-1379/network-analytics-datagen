#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy in a radio network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# A RadioNode is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=rn_2104
#
#[TODO] Fix this whole description
#
#
# An eRBS is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=erbs_2104
#
# An EUtranCellFDD is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=erbs_2104/ManagedElement=1/ENodeBFunction=1/EUtranCellFDD=2104-3
#
# A configuration file is also generated for each MO where the PM counter generation script requires additional information to operate.
# For example, each eRBS needs to state whether it is a G1 or G2 node, what node version it is, etc.
# In addition, the PM counter generation script uses the existence of this configuration file to determine whether or not to generate counters for this node.
# Removing this file will turn off counter generation for that node.
# After this script has generated the configuration file, it may be manually modified to alter any parameter, 
# e.g. to change the OSS_ID from eniq_oss_1 to eniq_oss_3 for testing purposes.
#
# Note however that rerunning this script will overwrite any locally modified versions.
#
# New managed objects may also be created after execution of this script by simply creating a file path to model the MO required.
# For example to add a new cell just execute the following command:
#    mkdir -p ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=erbs_2104/ManagedElement=1/ENodeBFunction=1/EUtranCellFDD=2104-4
#
# Note that the naming convention for cell ID is NODE_DIGITS-CELL, e.g. where eRBS ID is erbsG2_2104, the first cell will be:
#    SubNetwork=ONRM_RootMo/MeContext=erbs_2104/ManagedElement=1/ENodeBFunction=1/EUtranCellFDD=2104-1
#
# Similarly cell relations extend this by adding a relation suffix:
#    SubNetwork=ONRM_RootMo/MeContext=erbs_2104/ManagedElement=1/ENodeBFunction=1/EUtranCellFDD=2104-1/EUtranFreqRelation=750/EUtranCellRelation=2104-1-1
# 
# To create a list of cells:
#    for i in {7..9}; do mkdir -p ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=erbs_2104/ManagedElement=1/ENodeBFunction=1/EUtranCellFDD=2104-$i; done
#
# To aid identification during test, the numbering convention for nodes is that:
#   G1 nodes are in the range 1100-1999
#                  in OSS_1 : 1100-1199
#                  in OSS_2 : 1200-1299
#                  in OSS_3 : 1300-1399
#
#   G2 nodes are in the range 2100-2999 
#                  in OSS_1 : 2100-2199
#                  in OSS_2 : 2200-2299
#                  in OSS_3 : 2300-2399
#
# Also, the numbering convention for cells is that EUtranCellFDD range from 1 to 3, and EUtranCellTDD from 4 to 6.
#      EUtranCellFDD => [1 .. 3],
#      EUtranCellTDD => [4 .. 6],
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
 This script creates a Managed Object Model file structure for a Network Analytics Server feature.

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
my @bsc      = map { sprintf 'bsc_21%02d', $_ } 1 .. 5;
my @rnc      = map { sprintf 'rnc_21%02d', $_ } 1 .. 5;
my $root_dir = '/eniq/home/dcuser/ManagedObjects';

my @mandatory_sections    = qw(ATTRIBUTES COMMON METADATA);
my @optional_sections     = qw(GSM LTE WCDMA);
my @config_sections       = (@mandatory_sections, @optional_sections);
my $config_sections_match = "@config_sections";  # create a regex match pattern
$config_sections_match    =~ s/ /|/g;

# Remove old paths they exist and if --clean argument given
clean_old_paths(root_dir => $root_dir, node_prefix => 'MeContext\=rn_') if -d $root_dir and $clean;

my %node_model = (
   # These DEFAULT attributes are the CONFIGURATIONs for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ATTRIBUTES                => {
         daylightSavingsAdjust     => 1,
         fileFormatVersion         => '32.435 V8.0',
         managedElementType        => 'RadioNode',
         mcc                       => 272,
         mnc                       => 1,
         mncLength                 => 2,
         neMIMversion              => 'H.1.100',
         nodeVersion               => 'L17A',
         siteRef                   => '2000',
         swVersion                 => 'CXP102051/21_R38ES',
         timeZone                  => '+0100',
         vendorName                => 'Ericsson',
         worldTimeZoneId           => 'Europe/Dublin',
      },
      COMMON                   => {
         EnergyMeasurement         => [1],
      },
      GSM                      => {
         associatedBsc             => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[0]",
         TOPOLOGY_DIR              => 'gsm/topologyData/RADIO',
      },
      LTE                      => {
         Cdma20001xRttBandRelation => [1],
         Cdma20001xRttCellRelation => [1 .. 3],
         Cdma20001xRttFreqRelation => [1],
         EUtranCellFDD             => [1 .. 3],
         EUtranCellRelation        => [1 .. 10],
         EUtranFreqRelation        => [750, 775, 2175, 2200],
         GeranCellRelation         => [1 .. 3],
         SectorCarrier             => [1 .. 3],
         GeranFreqGroupRelation    => [1],
         TOPOLOGY_DIR              => 'lte/topologyData/ERBS', 
         UtranCellRelation         => [1 .. 6],
         UtranFreqRelation         => [2000, 2175, 2200],
      },
      METADATA                 => {
         CELL_TYPE                 => 'FDD',
         COMMON_OUTPUT_DIR         => 'RadioNode/COMMON',
         GENERATION                => 'G2',
         MAX_POWER                 => 40,                 # Maximum transmission power of a node in watts. Used for Energy Feature
         OSS_ID                    => 'eniq_oss_1',
         OUTPUT_DIR                => 'RadioNode/MIXED',
         POWER_VARIATION           => 3,                  # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
         PREFIX                    => 'enb_',
         RAT_TYPES                 => ['LTE'],
         REPORTING                 => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                  => $root_dir,
         ROOT_MO                   => $root_mo,
         ROP_LENGTH                => 900,
         SUBNETWORK                => 'LRAN',
      },
      WCDMA                    => {
         associatedRnc             => "SubNetwork=$root_mo,SubNetwork=$rnc[0],MeContext=$rnc[0]",
         TOPOLOGY_DIR              => 'utran/topologyData/RBS',
      },
   },
  Group_G2_TWAMP_Profile1A => {
      # TwampTestSession format is <SourceNodeType>-<DestinationNodeType>-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband_T-Signalling-40-1-50', 
               'Baseband_T-Baseband_T-Sync-54-1-50',
               'Baseband_T-Baseband_T-Voice-46-1-50',
               'Baseband_T-Baseband_T-Data-14-1-50',
               'Baseband_T-Baseband_T-Data_HSPA-18-1-50',
            ],
         },
      },
      Instances                => [1001 .. 1022],      
   },
   Group_G2_TWAMP_Profile1B => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband_T-Signalling-40-1-50', 
               'Baseband_T-Baseband_T-Voice-46-1-50',
               'Baseband_T-Baseband_T-Data-14-1-50',
               'Baseband_T-Baseband-Signalling-40-1-50', 
               'Baseband_T-Baseband-Voice-46-1-50',
               'Baseband_T-Baseband-Data-14-1-50',
            ],
         },
      },
      Instances                => [1023 .. 1025],      
   },
   Group_G2_TWAMP_Profile1C => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband-Signalling-40-1-50', 
               'Baseband_T-Baseband-Sync-54-1-50',
               'Baseband_T-Baseband_T-Signalling-40-1-50', 
               'Baseband_T-Baseband_T-Sync-54-1-50',
               'Baseband_T-EVO-Signalling-40-1-50', 
               'Baseband_T-EVO-Sync-54-1-50',
            ],
         },
      },
      Instances                => [1026 .. 1027],
   },
   Group_G2_TWAMP_Profile1D => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband-Sync-54-1-50',
               'Baseband_T-Baseband_T-Sync-54-1-50',
               'Baseband_T-DUS41_DUL20-Sync-54-1-50',
               'Baseband_T-EVO-Sync-54-1-50',
               'Baseband_T-SIU_TCU02-Sync-54-1-50',
               'Baseband_T-SSR_EPG-Sync-54-1-50',
            ],
         },
      },
      Instances                => [1028 .. 1029],      
   },
   Group_G2_TWAMP_Profile2 => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband_T-Signalling-40-2-50', 
               'Baseband_T-Baseband_T-Sync-54-2-50',
               'Baseband_T-Baseband_T-Voice-46-2-50',
               'Baseband_T-Baseband_T-Data-14-2-50',
               'Baseband_T-Baseband_T-Data_HSPA-18-2-50',
            ],
         },
      },
      Instances                => [1030 .. 1039],      
   },
   Group_G2_TWAMP_Profile1_SIU => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-SIU_TCU02-Signalling-40-1-50', 
               'Baseband_T-SIU_TCU02-Sync-54-1-50',
               'Baseband_T-SIU_TCU02-Voice-46-1-50',
               'Baseband_T-SIU_TCU02-Data-14-1-50',
               'Baseband_T-SIU_TCU02-Data_HSPA-18-1-50',
            ],
         },
      },
      Instances                => [1040 .. 1049],      
   },
   Group_G2_TWAMP_Baseband_Payload => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband_T-Signalling-40-1-250', 
               'Baseband_T-Baseband_T-Sync-54-1-250',
               'Baseband_T-Baseband_T-Voice-46-1-250',
               'Baseband_T-Baseband_T-Data-14-1-250',
               'Baseband_T-Baseband_T-Data_HSPA-18-1-250',
            ],
         },
      },
      Instances                => [1060 .. 1069],      
   },
   Group_G2_TWAMP_BasebandA => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband_T-Baseband-Signalling-40-1-50', 
               'Baseband_T-Baseband-Sync-54-1-50',
               'Baseband_T-Baseband-Voice-46-1-50',
               'Baseband_T-Baseband-Data-14-1-50',
               'Baseband_T-Baseband-Data_HSPA-18-1-50',
            ],
         },
      },
      Instances                => [1070 .. 1074],      
   },
   Group_G2_TWAMP_BasebandB => {
      # TwampTestSession format is NodeIndex-SourceNodeType-DestinationNodeType-Service-DSCP-Profile-PayloadSize
      CONFIGURATION            => {
         COMMON                   => {
            Router                   => [1],
            TwampInitiator           => [1],
            TwampTestSession         => [
               'Baseband-Baseband-Signalling-40-1-50', 
               'Baseband-Baseband-Voice-46-1-50',
               'Baseband-Baseband-Data-14-1-50',
            ],
         },
      },
      Instances                => [1075 .. 1183],      
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

   my $node_id = "$parameters{METADATA}{PREFIX}$node_index";
   print "node_id             = $node_id\n" if $debug;
   print "  parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   my $node_dir  = "$root_dir/SubNetwork=$parameters{METADATA}{ROOT_MO}/SubNetwork=$parameters{METADATA}{SUBNETWORK}/MeContext=$node_id"; 
   my $node_file = "$node_dir/$node_id.conf";
   print "node_dir  = $node_dir\n" if $debug;
   print "node_file = $node_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   my %file_parameters;
   $file_parameters{$_} = $parameters{$_} for (@mandatory_sections, @{ $parameters{METADATA}{RAT_TYPES} });
   # Create the configuration file for each node
   my $yaml = YAML::Tiny->new( \%file_parameters );
   $yaml->write( $node_file );

   print "  Model :\n", YAML::Tiny::Dump( \%{ $parameters{ManagedElement} } ) if $debug;

   # EquipmentSupportFunction MOs
   my $equipment_dir = "$node_dir/ManagedElement=1/EquipmentSupportFunction=1";

   for my $EnergyMeasurement (@{ $parameters{COMMON}{EnergyMeasurement} } ) {
      print "            EnergyMeasurement             = $EnergyMeasurement\n" if $debug;
      my $dir = "$equipment_dir/EnergyMeasurement=$node_index-$EnergyMeasurement";
      mkpath($dir) unless -d $dir;
   }
   
   # Transport MOs
   my $transport_dir = "$node_dir/ManagedElement=1/Transport=1";

   for my $Router (@{ $parameters{COMMON}{Router} } ) {
      print "            Router             = $Router\n" if $debug;
      for my $TwampInitiator (@{ $parameters{COMMON}{TwampInitiator} } ) {
         print "            TwampInitiator             = $TwampInitiator\n" if $debug;
         for my $TwampTestSession (@{ $parameters{COMMON}{TwampTestSession} } ) {
            print "            TwampTestSession             = $TwampTestSession\n" if $debug;
            my $dir = "$transport_dir/Router=$Router/TwampInitiator=$TwampInitiator/TwampTestSession=$node_index-$TwampTestSession";
            mkpath($dir) unless -d $dir;
         }
      }
   }

   my $rat_types = "@{ $parameters{METADATA}{RAT_TYPES} }";
   return unless $rat_types =~ m/LTE/;  # skip unless this node is LTE

   # ENodeBFunction MOs
   my $enodeb_dir = "$node_dir/ManagedElement=1/ENodeBFunction=1";

   for my $SectorCarrier (@{ $parameters{LTE}{SectorCarrier} } ) {
      print "            SectorCarrier             = $SectorCarrier\n" if $debug;
      my $dir = "$enodeb_dir/SectorCarrier=$node_index-$SectorCarrier";
      mkpath($dir) unless -d $dir;
   }

}

