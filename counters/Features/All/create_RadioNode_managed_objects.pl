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
         timeZone                  => '+0000',   # +0100 for summertime, +0000 for wintertime
         vendorName                => 'Ericsson',
         worldTimeZoneId           => 'Europe/Dublin',
      },
      COMMON                   => {
         ConsumedEnergyMeasurement => [],
         EFuse                     => [],
         EnergyMeasurement         => [1],
         EnergyMeter               => [],
         FieldReplaceableUnit      => [],
      },
      GSM                      => {
         associatedBsc             => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[0]",
         GsmSector                 => [1 .. 3],
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
         MAX_VOLTAGE               => -48,                # Maximum voltage in volts. Used for Energy Feature
         OSS_ID                    => 'eniq_oss_1',
         OUTPUT_DIR                => 'RadioNode/MIXED',
         POWER_VARIATION           => 3,                  # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
         PREFIX                    => 'rn_',
         RAT_TYPES                 => ['LTE'],
         REPORTING                 => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                  => $root_dir,
         ROOT_MO                   => $root_mo,
         ROP_LENGTH                => 900,
         SUBNETWORK                => 'LRAN',
         VOLTAGE_VARIATION         => 1,                  # The range of deviation (+/-) from baseline vooltage level in any given ROP. Used for Energy Feature
      },
      WCDMA                    => {
         associatedRnc             => "SubNetwork=$root_mo,SubNetwork=$rnc[0],MeContext=$rnc[0]",
         HsDschResources           => [],
         RbsLocalCell              => [],
         TOPOLOGY_DIR              => 'utran/topologyData/RBS',
      },
   },
   Group_18_1A => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION            => {
         ATTRIBUTES                => {
            neMIMversion               => 'K.18.100', # Select counters with some null values
            nodeVersion                => '18.Q1',
         },
         COMMON                   => {
            ConsumedEnergyMeasurement => [1],
            EFuse                     => [1 .. 2],
            EnergyMeasurement         => [],
            EnergyMeter               => [1 .. 2],
            FieldReplaceableUnit      => [1 .. 4],
         },
         METADATA                 => {
            MAX_POWER                 => 20,                 # Maximum transmission power of a node in watts. Used for Energy Feature
            POWER_VARIATION           => 5,                  # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
            RAT_TYPES                 => ['LTE', 'WCDMA', 'GSM'],
            VOLTAGE_VARIATION         => 2,                  # The range of deviation (+/-) from baseline vooltage level in any given ROP. Used for Energy Feature
         },
      },
      Instances                => [210080 .. 210089],      
   },
   Group_18_1B => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION            => {
         ATTRIBUTES                => {
            neMIMversion               => 'K.18.100', # Select counters with some null values
            nodeVersion                => '18.Q1',
         },
         COMMON                   => {
            ConsumedEnergyMeasurement => [1],
            EFuse                     => [1 .. 6],
            EnergyMeasurement         => [],
            EnergyMeter               => [1],
            FieldReplaceableUnit      => [1 .. 2],
         },
         METADATA                 => {
            RAT_TYPES                 => ['LTE', 'WCDMA'],
         },
      },
      Instances                => [210090 .. 210099],      
   },
   Group_18_TDD => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION            => {
         ATTRIBUTES                => {
            neMIMversion               => 'K.18.100', # Select counters with some null values
            nodeVersion                => '18.Q1',
         },
         COMMON                   => {
            ConsumedEnergyMeasurement => [1],
            EFuse                     => [1 .. 3],
            EnergyMeasurement         => [],
            EnergyMeter               => [1],
            FieldReplaceableUnit      => [1 .. 2],
         },
         METADATA                 => {
            CELL_TYPE                  => 'TDD',
         },
         LTE                       => {
            EUtranCellFDD              => [],
            EUtranCellTDD              => [4 .. 6],
         },
      },
      Instances                => [210055 .. 210056],      
   },

   Group_18_FDD_and_TDD => {
      # FDD and TDD
      CONFIGURATION            => {
         ATTRIBUTES               => {
            neMIMversion              => 'K.18.100', # Select counters with some null values
            nodeVersion               => '18.Q1',
         },
         COMMON                   => {
            ConsumedEnergyMeasurement => [1],
            EFuse                     => [1 .. 3],
            EnergyMeasurement         => [],
            EnergyMeter               => [1],
            FieldReplaceableUnit      => [1 .. 2],
         },
         LTE                      => {
            EUtranCellTDD             => [4 .. 6],
            SectorCarrier             => [1 .. 6],
         },
         METADATA                 => {
            CELL_TYPE                 => 'FDD+TDD',
         },
      },
      Instances                => [210057],
   },
 


   Group_G2 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION            => {
         ATTRIBUTES                => {
            neMIMversion               => 'G.1.301', # Select counters with some null values
            nodeVersion                => 'L16B',
         },
      },
      Instances                => [210001 .. 210010],      
   },
   Group_G2_Not_Reporting => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION            => {
         METADATA                 => {
            REPORTING                 => 0,                  # 1 = Reporting, 0 = Not Reporting 
         },
      },
      Instances                => [210011 .. 210015],      
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
      Instances                => [210020 .. 210022],      
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
      Instances                => [210023 .. 210025],      
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
      Instances                => [210026 .. 210027],
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
      Instances                => [210028 .. 210029],      
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
      Instances                => [210030 .. 210039],      
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
      Instances                => [210040 .. 210049],      
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
      Instances                => [210060 .. 210069],      
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
      Instances                => [210070 .. 210074],      
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
      Instances                => [210075 .. 210079],      
   },
   Group_G2_All_RATs_Controller_1 => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[0]",
         },
         METADATA                  => {
            MAX_POWER                  => 120,
            POWER_VARIATION            => 10,
            RAT_TYPES                  => ['LTE', 'WCDMA', 'GSM'],
            SUBNETWORK                 => 'RAN',
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[0],MeContext=$rnc[0]",
         },
       },
      Instances                => [210101 .. 210105],      
   },
   # WCDMA nodes have to be contiguous, so that cells map to RBSs
   # Cells 1-3 are RBS-1
   # Cells 4-6 are RBS-2, etc
   Group_G2_LTE_and_WCDMA => {
      CONFIGURATION            => {
        METADATA                   => {
            MAX_POWER                  => 20,
            POWER_VARIATION            => 5,
            RAT_TYPES                  => ['LTE', 'WCDMA'],
            SUBNETWORK                 => 'RAN',
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[0],MeContext=$rnc[0]",
         },
      },
      Instances                => [210106 .. 210107],
   },
   Group_G2_WCDMA_Only => {
      CONFIGURATION            => {
        METADATA                   => {
            MAX_POWER                  => 20,
            POWER_VARIATION            => 5,
            RAT_TYPES                  => ['WCDMA'],
            SUBNETWORK                 => 'WRAN', 
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[2],MeContext=$rnc[2]",
         },
       },
      Instances                => [210308 .. 210310],
   },
   Group_G2_WCDMA_Only_17B => {
      CONFIGURATION            => {
         ATTRIBUTES                => {
            neMIMversion              => 'J.2.200',
            nodeVersion               => 'L17B',
         },
         METADATA                   => {
            MAX_POWER                  => 20,
            POWER_VARIATION            => 5,
            RAT_TYPES                  => ['WCDMA'],
            SUBNETWORK                 => $rnc[2],
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[2],MeContext=$rnc[2]",
            HsDschResources            => [1],
            RbsLocalCell               => [1 .. 3],
         },
       },
      Instances                => [210311 .. 210315],      
   },
   Group_G2_All_RATs_Controller_2 => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[1]",
         },
         METADATA                  => {
            MAX_POWER                  => 120,
            POWER_VARIATION            => 10,
            RAT_TYPES                  => ['LTE', 'WCDMA', 'GSM'],
            SUBNETWORK                 => 'RAN',
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[1],MeContext=$rnc[1]",
         },
       },
      Instances                => [210201 .. 210205],      
   },
   Group_G2_All_RATs_Controller_3 => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[2]",
         },
         METADATA                  => {
            MAX_POWER                  => 120,
            POWER_VARIATION            => 10,
            RAT_TYPES                  => ['LTE', 'WCDMA', 'GSM'],
            SUBNETWORK                 => 'RAN',
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[2],MeContext=$rnc[2]",
         },
       },
      Instances                => [210301 .. 210305],      
   },
   Group_G2_All_RATs_Controller_4 => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[3]",
         },
         METADATA                  => {
            MAX_POWER                  => 120,
            POWER_VARIATION            => 10,
            RAT_TYPES                  => ['LTE', 'WCDMA', 'GSM'],
            SUBNETWORK                 => 'RAN',
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[3],MeContext=$rnc[3]",
         },
       },
      Instances                => [210401 .. 210405],      
   },
   Group_G2_All_RATs_Controller_5 => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[4]",
         },
         METADATA                  => {
            MAX_POWER                  => 120,
            POWER_VARIATION            => 10,
            RAT_TYPES                  => ['LTE', 'WCDMA', 'GSM'],
            SUBNETWORK                 => 'RAN',
         },
         WCDMA                     => {
            associatedRnc              => "SubNetwork=$root_mo,SubNetwork=$rnc[4],MeContext=$rnc[4]",
         },
       },
      Instances                => [210501 .. 210505],      
   },
   Group_G2_LTE_and_GSM => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[0]",
         },
         METADATA                  => {
            MAX_POWER                  => 80,
            POWER_VARIATION            => 10,
            RAT_TYPES                  => ['LTE', 'GSM'],
            SUBNETWORK                 => 'RAN',
         },
      },
      Instances                => [210131 .. 210132],      
   },
   Group_G2_GSM_Only => {
      CONFIGURATION            => {
         GSM                       => {
            associatedBsc              => "SubNetwork=$root_mo,SubNetwork=GRAN,MeContext=$bsc[2]",
         },
        METADATA                   => {
            MAX_POWER                  => 20,
            POWER_VARIATION            => 5,
            RAT_TYPES                  => ['GSM'],
            SUBNETWORK                 => 'GRAN',
         },
      },
      Instances                => [210161 .. 210163],      
   },
   Group_G2_more_EUtranCellRelations => {
      # More EUtranCellRelations
      CONFIGURATION            => {
        LTE                       => {
           EUtranCellRelation          => [1 .. 20],
         },
         METADATA                  => {
            MAX_POWER                  => 40,
            POWER_VARIATION            => 10,
         },
      },
      Instances                => [210051],
   },
   Group_G2_no_Cdma20001xRttCellRelations => {
      # Different version, and no Cdma20001xRttCellRelations
      CONFIGURATION            => {
        LTE                       => {                           
            Cdma20001xRttCellRelation => [],
         },
         METADATA                  => {
            MAX_POWER                  => 120,
            POWER_VARIATION            => 10,
         },
      },
      Instances                => [210052],
   },
   Group_G2_TDD_only => {
      # TDD only. Note that local list of EUtranCellFDDs is empty.
      CONFIGURATION            => {
         METADATA                  => {
            CELL_TYPE                  => 'TDD',
         },
         LTE                       => {
            EUtranCellFDD              => [],
            EUtranCellTDD              => [4 .. 6],
         },
      },
      Instances                => [210053],
   },
   Group_G2_FDD_and_TDD => {
      # FDD and TDD
      CONFIGURATION            => {
         COMMON                    => {
            EnergyMeasurement          => [1 .. 3],
         },
         LTE                       => {
            EUtranCellTDD              => [4 .. 6],
            SectorCarrier              => [1 .. 6],
         },
         METADATA                  => {
            CELL_TYPE                  => 'FDD+TDD',
         },
      },
      Instances                => [210054],
   },
   Group_G2_OSS_2 => {
      # These CONFIGURATION attributes are the additional defaults for all Group_G2_OSS_2 Managed Objects unless overridden by local versions
      CONFIGURATION            => {
         METADATA                  => {
            OSS_ID                     => 'eniq_oss_2',
         },
      },
      Instances                => [220001 .. 220002],
   },
   Group_G2_OSS_3 => {
      # These CONFIGURATION attributes are the additional defaults for all Group_G2_OSS_3 Managed Objects unless overridden by local versions
      CONFIGURATION           => {
         METADATA                 => {
            OSS_ID                    => 'eniq_oss_3',
         },
      },
      Instances               => [230001 .. 230002],
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

   # EnergyMeter MOs
   my $Equipment_dir = "$node_dir/ManagedElement=1/Equipment=1";

   for my $FieldReplaceableUnit (@{ $parameters{COMMON}{FieldReplaceableUnit} } ) {
      print "            FieldReplaceableUnit             = $FieldReplaceableUnit\n" if $debug;
      my $FieldReplaceableUnit_dir = "$Equipment_dir/FieldReplaceableUnit=$FieldReplaceableUnit";
      mkpath($FieldReplaceableUnit_dir) unless -d $FieldReplaceableUnit_dir;
      for my $EnergyMeter (@{ $parameters{COMMON}{EnergyMeter} } ) {
         print "            EnergyMeter             = $EnergyMeter\n" if $debug;
         my $EnergyMeter_dir = "$FieldReplaceableUnit_dir/EnergyMeter=$EnergyMeter";
         mkpath($EnergyMeter_dir) unless -d $EnergyMeter_dir;
      }
      for my $EFuse (@{ $parameters{COMMON}{EFuse} } ) {
         print "            EFuse             = $EFuse\n" if $debug;
         my $EFuse_dir = "$FieldReplaceableUnit_dir/EFuse=$EFuse";
         mkpath($EFuse_dir) unless -d $EFuse_dir;
         for my $EnergyMeter (@{ $parameters{COMMON}{EnergyMeter} } ) {
            print "            EnergyMeter             = $EnergyMeter\n" if $debug;
            my $EnergyMeter_dir = "$EFuse_dir/EnergyMeter=$EnergyMeter";
            mkpath($EnergyMeter_dir) unless -d $EnergyMeter_dir;
         }
      }
   }

   # ConsumedEnergyMeasurement MOs
   my $NodeSupport_dir = "$node_dir/ManagedElement=1/NodeSupport=1";

   for my $ConsumedEnergyMeasurement (@{ $parameters{COMMON}{ConsumedEnergyMeasurement} } ) {
      print "            ConsumedEnergyMeasurement             = $ConsumedEnergyMeasurement\n" if $debug;
      my $ConsumedEnergyMeasurement_dir = "$NodeSupport_dir/ConsumedEnergyMeasurement=$ConsumedEnergyMeasurement";
      mkpath($ConsumedEnergyMeasurement_dir) unless -d $ConsumedEnergyMeasurement_dir;
   }

   # EquipmentSupportFunction MOs
   my $equipment_dir = "$node_dir/ManagedElement=1/EquipmentSupportFunction=1";

   for my $EnergyMeasurement (@{ $parameters{COMMON}{EnergyMeasurement} } ) {
      print "            EnergyMeasurement             = $EnergyMeasurement\n" if $debug;
      my $dir = "$equipment_dir/EnergyMeasurement=$node_index-$EnergyMeasurement";
      mkpath($dir) unless -d $dir;
   }
   
   # BtsFunction MOs
   my $bts_dir = "$node_dir/ManagedElement=1/BtsFunction=1";

   for my $GsmSector (@{ $parameters{GSM}{GsmSector} } ) {
      print "            GsmSector             = $GsmSector\n" if $debug;
      my $dir = "$bts_dir/GsmSector=$node_index-$GsmSector";
      mkpath($dir) unless -d $dir;
   }

   # NodeBFunction MOs
   my $nodeb_dir = "$node_dir/ManagedElement=1/NodeBFunction=1";

   for my $RbsLocalCell (@{ $parameters{WCDMA}{RbsLocalCell} } ) {
      print "            RbsLocalCell             = $RbsLocalCell\n" if $debug;
      my $dir = "$nodeb_dir/RbsLocalCell=$RbsLocalCell";
      mkpath($dir) unless -d $dir;

      for my $HsDschResources (@{ $parameters{WCDMA}{HsDschResources} } ) {
         print "            HsDschResources             = $HsDschResources\n" if $debug;
         my $hs_dir = "$dir/HsDschResources=$HsDschResources";
         mkpath($hs_dir) unless -d $hs_dir;
      }
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

   for my $cell_type ( qw(EUtranCellFDD EUtranCellTDD) ) {
      for my $EUtranCell (@{ $parameters{LTE}{$cell_type} } ) {
         print "\n            $cell_type             = $EUtranCell\n" if $debug;
         for my $EUtranFreqRelation (@{ $parameters{LTE}{EUtranFreqRelation} } ) {
            print "               EUtranFreqRelation        = $EUtranFreqRelation\n" if $debug;   
            for my $EUtranCellRelation (@{ $parameters{LTE}{EUtranCellRelation} } ) {
               print "                  EUtranCellRelation        = $EUtranCellRelation\n" if $debug;
               my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/EUtranFreqRelation=$EUtranFreqRelation/EUtranCellRelation=$node_index-$EUtranCell-$EUtranCellRelation";
               mkpath($dir) unless -d $dir;
            }
            for my $UtranFreqRelation (@{ $parameters{LTE}{UtranFreqRelation} } ) {
               print "               UtranFreqRelation         = $UtranFreqRelation\n" if $debug; 
               for my $UtranCellRelation (@{ $parameters{LTE}{UtranCellRelation} } ) {
                  print "                  UtranCellRelation         = $UtranCellRelation\n" if $debug;
                  my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/UtranFreqRelation=$UtranFreqRelation/UtranCellRelation=$node_index-$EUtranCell-$UtranCellRelation";
                  mkpath($dir) unless -d $dir;
               }
            }

            for my $GeranFreqGroupRelation (@{ $parameters{LTE}{GeranFreqGroupRelation} } ) {
               print "               GeranFreqGroupRelation    = $GeranFreqGroupRelation\n" if $debug;
               for my $GeranCellRelation (@{ $parameters{LTE}{GeranCellRelation} } ) {
                  print "                  GeranCellRelation         = $GeranCellRelation\n" if $debug;
                  my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/GeranFreqGroupRelation=$GeranFreqGroupRelation/GeranCellRelation=$node_index-$EUtranCell-$GeranCellRelation";
                  mkpath($dir) unless -d $dir;
               }
            }

            for my $Cdma20001xRttBandRelation (@{ $parameters{LTE}{Cdma20001xRttBandRelation} } ) {
               print "               Cdma20001xRttBandRelation = $Cdma20001xRttBandRelation\n" if $debug;
               for my $Cdma20001xRttFreqRelation (@{ $parameters{LTE}{Cdma20001xRttFreqRelation} } ) {
                  print "                  Cdma20001xRttFreqRelation = $Cdma20001xRttFreqRelation\n" if $debug;
                  for my $Cdma20001xRttCellRelation (@{ $parameters{LTE}{Cdma20001xRttCellRelation} } ) {
                     print "                     Cdma20001xRttCellRelation = $Cdma20001xRttCellRelation\n" if $debug;
                     my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/Cdma20001xRttBandRelation=$Cdma20001xRttBandRelation/Cdma20001xRttFreqRelation=$Cdma20001xRttFreqRelation/Cdma20001xRttCellRelation=$node_index-$EUtranCell-$Cdma20001xRttCellRelation";
                     mkpath($dir) unless -d $dir;
                 }
               }
            }
         }
      }
   }
}

