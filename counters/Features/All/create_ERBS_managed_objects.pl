#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy in an LTE radio network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
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
# Note that the naming convention for cell ID is ERBS_DIGITS-CELL, e.g. where eRBS ID is erbsG2_2104, the first cell will be:
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
use YAML::Tiny;
use File::Path;
use Carp;
use Getopt::Long;

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

my $root_dir          = '/eniq/home/dcuser/ManagedObjects';

# Remove old paths they exist and if --clean argument given
rmtree($root_dir) if -d $root_dir and $clean;

my %erbs_model = (
   # These DEFAULT attributes are the defaults for all Managed Objects unless overridden by local versions
   DEFAULT => {
      ROOT_DIR                  => $root_dir,
      Cdma20001xRttBandRelation => [1],
      Cdma20001xRttCellRelation => [1 .. 3],
      Cdma20001xRttFreqRelation => [1],
      CELL_TYPE                 => 'FDD',
      ConsumedEnergy            => [],
      daylightSavingsAdjust     => 1,
      EBS_COUNTERS              => ['pmTaDistr'],     # List of counters that are from Event Based Statistics
      EBS_OUTPUT_DIR            => 'event_data/lte_event_stat_file',
      EBS_EVENTS_ID             => 'eniq_events_1',
      EBS_OSS_ID                => 'events_oss_1',
      Equipment                 => [1],
      EnergyMeasurement         => [1],
      EUtranCellFDD             => [1 .. 3],
      EUtranCellRelation        => [1 .. 10],
      EUtranFreqRelation        => [750, 775, 2175, 2200],
      fileFormatVersion         => '32.435 V8.0',
      GeranCellRelation         => [1 .. 3],
      GeranFreqGroupRelation    => [1],
      MAX_POWER                 => 40,                # Maximum transmission power of a node in watts. Used for Energy Feature
      MAX_VOLTAGE               => -48,               # Maximum voltage in volts. Used for Energy Feature
      mcc                       => 353,
      mnc                       => 87,
      mncLength                 => 2,
      neMIMversion              => 'H.1.100',
      nodeVersion               => 'L17A',
      OSS_ID                    => 'eniq_oss_1',
      PmUlInterferenceReport    => [1 .. 2],
      POWER_VARIATION           => 3,                  # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
      PREFIX                    => 'erbs_',
      REPORTING                 => 1,                  # 1 = Reporting, 0 = Not Reporting 
      ROOT_MO                   => 'ONRM_RootMo',
      ROP_LENGTH                => 900,
      SectorCarrier             => [1 .. 3],
      siteRef                   => '1000',
      Slot                      => [1 .. 2],
      SUBNETWORK                => 'LRAN',
      swVersion                 => 'CXP102051/21_R38ES',
      timeZone                  => '+0100',
      UtranCellRelation         => [1 .. 6],
      UtranFreqRelation         => [2000, 2175, 2200],
      vendorName                => 'Ericsson',
      VOLTAGE_VARIATION         => 1,                  # The range of deviation (+/-) from baseline vooltage level in any given ROP. Used for Energy Feature
      worldTimeZoneId           => 'Europe/Dublin',
   },
   Group_G1 => {
      # These DEFAULT attributes are the additional defaults for all Group_G1 Managed Objects unless overridden by local versions
      DEFAULT => {
         GENERATION                => 'G1',
         Instances                 => [1113 .. 1130],
         managedElementType        => 'ERBS',
         OUTPUT_DIR                => 'lterbs',
      },
      # Create some nodes with a different NE MIM version, with some variations on NULL counters
      1101 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.101',
      },
      1102 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.102',
      },
      1103 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.103',
      },
      1104 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.104',
      },
      1105 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.105',
      },
      1106 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.106',
      },
      1107 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.107',
      },
      1108 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.108',
      },
      1109 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.109',
      },
      1110 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.110',
      },
      1111 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.111',
      },
      1112 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.112',
      },
      # Create a node with a different version
      1151 => {
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.100',
         MAX_POWER                 => 80,
         POWER_VARIATION           => 6,
      },
      # Different version
      1152 => {
         nodeVersion               => 'L15B',
         neMIMversion              => 'F.1.100',
         MAX_POWER                 => 20,
      },
      # TDD only. Note that local list of EUtranCellFDDs is empty.
      1153 => {
         CELL_TYPE                 => 'TDD',
         EUtranCellFDD             => [],
         EUtranCellTDD             => [4 .. 6],
      },
      # FDD and TDD
      1154 => {
         CELL_TYPE                 => 'FDD+TDD',
         EUtranCellTDD             => [4 .. 6],
         SectorCarrier             => [1 .. 6],
      },
      # More relations
      1155 => {
         EUtranCellRelation        => [1 .. 30],
      },
      # Multiple EnergyMeasurements
      1156 => {
         EnergyMeasurement         => [1 .. 3],
         MAX_POWER                 => 20,
      },
      1161 => {
         neMIMversion              => 'H.1.101',
      },
      1162 => {
         neMIMversion              => 'H.1.101',
      },
      1163 => {
         neMIMversion              => 'H.1.101',
      },
    },
   Group_G1_OSS_2 => {
      # These DEFAULT attributes are the additional defaults for all Group_G1_OSS_2 Managed Objects unless overridden by local versions
      DEFAULT => {
         EBS_EVENTS_ID             => 'eniq_events_2',
         EBS_OSS_ID                => 'events_oss_2',
         GENERATION                => 'G1',
         Instances                 => [1201 .. 1220],
         managedElementType        => 'ERBS',
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.101',
         OSS_ID                    => 'eniq_oss_2',
         OUTPUT_DIR                => 'lterbs',
      },
   },
   Group_G1_OSS_3 => {
      # These DEFAULT attributes are the additional defaults for all Group_G1_OSS_3 Managed Objects unless overridden by local versions
      DEFAULT => {
         EBS_EVENTS_ID             => 'eniq_events_3',
         EBS_OSS_ID                => 'events_oss_3',
         GENERATION                => 'G1',
         Instances                 => [1301 .. 1335],
         managedElementType        => 'ERBS',
         nodeVersion               => 'L16A',
         neMIMversion              => 'G.1.101',
         OSS_ID                    => 'eniq_oss_3',
         OUTPUT_DIR                => 'lterbs',
      },
   },
   Group_G1_OSS_3_MSA => {
      # These DEFAULT attributes are the additional defaults for all Group_G1_OSS_3_MSA Managed Objects unless overridden by local versions
      DEFAULT => {
         EBS_EVENTS_ID             => 'eniq_events_3',
         EBS_OSS_ID                => 'events_oss_3',
         GENERATION                => 'G1',
         Instances                 => [1326 .. 1328],
         managedElementType        => 'ERBS',
         nodeVersion               => 'L17A',
         neMIMversion              => 'H.1.100',
         OSS_ID                    => 'eniq_oss_3',
         OUTPUT_DIR                => 'lterbs',
      },
   },
   Group_L18 => {
      # These DEFAULT attributes are the additional defaults for all Group_L18 Managed Objects unless overridden by local versions
      DEFAULT => {
         AuxPluginUnit             => ['RU-1-'], # This is a prefix, add RbsSlot index to get full instance name, e.g. RU-1-1, RU-1-2
         ConsumedEnergy            => [1],
         EnergyMeter               => [1],
         EBS_EVENTS_ID             => 'eniq_events_1',
         EBS_OSS_ID                => 'events_oss_1',
         EnergyMeasurement         => [],               # Deprecated in 17.3 
         HwUnit                    => ['PSU-1', 'PSU-2'],
         GENERATION                => 'G1',
         Instances                 => [1170 .. 1189],
         managedElementType        => 'ERBS',
         nodeVersion               => '18.Q1',
         neMIMversion              => 'K.18.100',
         OSS_ID                    => 'eniq_oss_1',
         OUTPUT_DIR                => 'lterbs',
         RbsSlot                   => [1 .. 4],
         RbsSubrack                => [1],
      },
   },   
);

#print "erbs_model :\n", YAML::Tiny::Dump( \%erbs_model ) if $debug;


for my $grouping (sort keys %erbs_model) {
   next if $grouping eq 'DEFAULT';
   my %parameters = %{ $erbs_model{DEFAULT} };                                                          # set default values
   $parameters{$_} = $erbs_model{$grouping}{DEFAULT}{$_} for keys %{ $erbs_model{$grouping}{DEFAULT} }; # override with grouping parameters
   for my $node_index (@{ $erbs_model{$grouping}{DEFAULT}{Instances} } ) {
      create_managed_objects($node_index, %parameters);
   }

   for my $node_index (sort keys %{ $erbs_model{$grouping} }) {
      next if $node_index eq 'DEFAULT';
      my %parameters = %{ $erbs_model{DEFAULT} };                                                                  # set default values
      $parameters{$_} = $erbs_model{$grouping}{DEFAULT}{$_}     for keys %{ $erbs_model{$grouping}{DEFAULT} };     # override with grouping parameters
      $parameters{$_} = $erbs_model{$grouping}{$node_index}{$_} for keys %{ $erbs_model{$grouping}{$node_index} }; # override with Instance parameters
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

   my $erbs_id = "$parameters{PREFIX}$node_index";
   print "erbs_id             = $erbs_id\n" if $debug;
   print "  parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   my $node_dir = "$root_dir/SubNetwork=$parameters{ROOT_MO}/SubNetwork=$parameters{SUBNETWORK}/MeContext=$erbs_id"; 
   print "node_dir = $node_dir\n" if $debug;

   my $erbs_file   = "$node_dir/$erbs_id.conf";
   print "erbs_file = $erbs_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   # Create the configuration file for each ERBS
   my $yaml = YAML::Tiny->new( \%parameters );
   $yaml->write( $erbs_file );

   print "  Model :\n", YAML::Tiny::Dump( \%{ $parameters{ManagedElement} } ) if $debug;

   # Equipment MOs
   my $equipment_dir = "$node_dir/ManagedElement=1/Equipment=1";

   for my $Equipment (@{ $parameters{Equipment} } ) {
      print "            Equipment             = $Equipment\n" if $debug;
      my $Equipment_dir = "$node_dir/ManagedElement=1/Equipment=$Equipment";
      mkpath($Equipment_dir) unless -d $Equipment_dir;
      for my $HwUnit (@{ $parameters{HwUnit} } ) {
         print "            HwUnit             = HwUnit\n" if $debug;
         my $HwUnit_dir = "$Equipment_dir/HwUnit=$HwUnit";
         mkpath($HwUnit_dir) unless -d $HwUnit_dir;
         for my $EnergyMeter (@{ $parameters{EnergyMeter} } ) {
            print "            EnergyMeter             = EnergyMeter\n" if $debug;
            my $EnergyMeter_dir = "$HwUnit_dir/EnergyMeter=$EnergyMeter";
            mkpath($EnergyMeter_dir) unless -d $EnergyMeter_dir;
         }
      }
      for my $RbsSubrack (@{ $parameters{RbsSubrack} } ) {
         print "            RbsSubrack             = RbsSubrack\n" if $debug;
         my $RbsSubrack_dir = "$Equipment_dir/RbsSubrack=$RbsSubrack";
         mkpath($RbsSubrack_dir) unless -d $RbsSubrack_dir;
         for my $RbsSlot (@{ $parameters{RbsSlot} } ) {
            print "            RbsSlot             = RbsSlot\n" if $debug;
            my $RbsSlot_dir = "$RbsSubrack_dir/RbsSlot=$RbsSlot";
            mkpath($RbsSlot_dir) unless -d $RbsSlot_dir;
            for my $AuxPluginUnit (@{ $parameters{AuxPluginUnit} } ) {
                print "            AuxPluginUnit             = AuxPluginUnit\n" if $debug;
                my $AuxPluginUnit_dir = "$RbsSlot_dir/AuxPluginUnit=$AuxPluginUnit$RbsSlot";
                mkpath($AuxPluginUnit_dir) unless -d $AuxPluginUnit_dir;
                for my $EnergyMeter (@{ $parameters{EnergyMeter} } ) {
                    print "            EnergyMeter             = EnergyMeter\n" if $debug;
                    my $EnergyMeter_dir = "$AuxPluginUnit_dir/EnergyMeter=$EnergyMeter";
                    mkpath($EnergyMeter_dir) unless -d $EnergyMeter_dir;
                }
            }
         }
      }
   }

   for my $ConsumedEnergy (@{ $parameters{ConsumedEnergy} } ) {
      print "            ConsumedEnergy             = $ConsumedEnergy\n" if $debug;
      my $ConsumedEnergy_dir = "$node_dir/ManagedElement=1/ConsumedEnergy=$ConsumedEnergy";
      mkpath($ConsumedEnergy_dir) unless -d $ConsumedEnergy_dir;
   }

   for my $EnergyMeasurement (@{ $parameters{EnergyMeasurement} } ) {
      print "            EnergyMeasurement             = $EnergyMeasurement\n" if $debug;
      my $EnergyMeasurement_dir = "$node_dir/ManagedElement=1/EquipmentSupportFunction=1/EnergyMeasurement=$node_index-$EnergyMeasurement";
      mkpath($EnergyMeasurement_dir) unless -d $EnergyMeasurement_dir;
   }

   # NodeBFunction MOs
   my $enodeb_dir = "$node_dir/ManagedElement=1/ENodeBFunction=1";

   for my $SectorCarrier (@{ $parameters{SectorCarrier} } ) {
      print "            SectorCarrier             = $SectorCarrier\n" if $debug;
      my $dir = "$enodeb_dir/SectorCarrier=$node_index-$SectorCarrier";
      mkpath($dir) unless -d $dir;
      for my $PmUlInterferenceReport (@{ $parameters{PmUlInterferenceReport} } ) {
         print "            PmUlInterferenceReport             = PmUlInterferenceReport\n" if $debug;
         my $dir = "$enodeb_dir/SectorCarrier=$node_index-$SectorCarrier/PmUlInterferenceReport=$PmUlInterferenceReport";
         mkpath($dir) unless -d $dir;
      }
   }

   # BbProcessingResource MOs
   for my $Slot (@{ $parameters{Slot} } ) {
      my $bbProcessingResource_dir = "$node_dir/ManagedElement=1/Equipment=1/Subrack=1/Slot=$Slot/PlugInUnit=1/DeviceGroup=dul/BbProcessingResource=1";
      mkpath($bbProcessingResource_dir) unless -d $bbProcessingResource_dir;
   }

   # MpProcessingResource MOs
   my $mpProcessingResource_dir = "$node_dir/ManagedElement=1/Equipment=1/Subrack=1/Slot=1/PlugInUnit=1/DeviceGroup=dul/MpProcessingResource=1";
   mkpath($mpProcessingResource_dir) unless -d $mpProcessingResource_dir;


   for my $cell_type ( qw(EUtranCellFDD EUtranCellTDD) ) {
      for my $EUtranCell (@{ $parameters{$cell_type} } ) {
         print "\n            $cell_type             = $EUtranCell\n" if $debug;
         for my $EUtranFreqRelation (@{ $parameters{EUtranFreqRelation} } ) {
            print "               EUtranFreqRelation        = $EUtranFreqRelation\n" if $debug;   
            for my $EUtranCellRelation (@{ $parameters{EUtranCellRelation} } ) {
               print "                  EUtranCellRelation        = $EUtranCellRelation\n" if $debug;
               my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/EUtranFreqRelation=$EUtranFreqRelation/EUtranCellRelation=$node_index-$EUtranCell-$EUtranCellRelation";
               mkpath($dir) unless -d $dir;
            }
            for my $UtranFreqRelation (@{ $parameters{UtranFreqRelation} } ) {
               print "               UtranFreqRelation         = $UtranFreqRelation\n" if $debug; 
               for my $UtranCellRelation (@{ $parameters{UtranCellRelation} } ) {
                  print "                  UtranCellRelation         = $UtranCellRelation\n" if $debug;
                  my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/UtranFreqRelation=$UtranFreqRelation/UtranCellRelation=$node_index-$EUtranCell-$UtranCellRelation";
                  mkpath($dir) unless -d $dir;
               }
            }

            for my $GeranFreqGroupRelation (@{ $parameters{GeranFreqGroupRelation} } ) {
               print "               GeranFreqGroupRelation    = $GeranFreqGroupRelation\n" if $debug;
               for my $GeranCellRelation (@{ $parameters{GeranCellRelation} } ) {
                  print "                  GeranCellRelation         = $GeranCellRelation\n" if $debug;
                  my $dir = "$enodeb_dir/$cell_type=$node_index-$EUtranCell/GeranFreqGroupRelation=$GeranFreqGroupRelation/GeranCellRelation=$node_index-$EUtranCell-$GeranCellRelation";
                  mkpath($dir) unless -d $dir;
               }
            }

            for my $Cdma20001xRttBandRelation (@{ $parameters{Cdma20001xRttBandRelation} } ) {
               print "               Cdma20001xRttBandRelation = $Cdma20001xRttBandRelation\n" if $debug;
               for my $Cdma20001xRttFreqRelation (@{ $parameters{Cdma20001xRttFreqRelation} } ) {
                  print "                  Cdma20001xRttFreqRelation = $Cdma20001xRttFreqRelation\n" if $debug;
                  for my $Cdma20001xRttCellRelation (@{ $parameters{Cdma20001xRttCellRelation} } ) {
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

