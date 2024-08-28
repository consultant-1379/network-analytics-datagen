#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy in a 5G radio network.
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
clean_old_paths(root_dir => $root_dir, node_prefix => 'MeContext\=nr_') if -d $root_dir and $clean;

my %node_model = (
   # These DEFAULT attributes are the CONFIGURATIONs for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ATTRIBUTES                => {
         daylightSavingsAdjust     => 1,
         fileFormatVersion         => '32.435 V10.0',
         managedElementType        => '5GRadioNode',
         mcc                       => 272,
         mnc                       => 1,
         mncLength                 => 2,
         neMIMversion              => 'L.18.400',
         nodeVersion               => '18.Q4',
         siteRef                   => '2000',
         swVersion                 => 'CXP2010045_5 R5A10',
         timeZone                  => '+0100',
         vendorName                => 'Ericsson',
         worldTimeZoneId           => 'Europe/Dublin',
      },
      COMMON                   => {
         ConsumedEnergyMeasurement => [1],
         EFuse                     => [1 .. 2],
         EnergyMeter               => [1 .. 2],
         FieldReplaceableUnit      => [1 .. 4],
      },
      NR                       => {
         GNBCUCPFunction           => [1],
         NRCellCU                  => [1 .. 6],
         GNBDUFunction             => [1],
         NRCellDU                  => [1 .. 6],
         TOPOLOGY_DIR              => 'nr/topologyData/5GRadioNode', 
      },
      METADATA                 => {
         CELL_TYPE                 => 'FDD',
         COMMON_OUTPUT_DIR         => 'RadioNode/COMMON',
         GENERATION                => 'G2',
         MAX_POWER                 => 40,                 # Maximum transmission power of a node in watts. Used for Energy Feature
         MAX_VOLTAGE               => -48,                # Maximum voltage in volts. Used for Energy Feature
         OSS_ID                    => 'eniq_oss_1',
         OUTPUT_DIR                => '5GRadioNode',
         POWER_VARIATION           => 3,                  # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
         PREFIX                    => 'nr_',
         RAT_TYPES                 => ['NR'],
         REPORTING                 => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                  => $root_dir,
         ROOT_MO                   => $root_mo,
         ROP_LENGTH                => 900,
         SUBNETWORK                => '5G',
         VOLTAGE_VARIATION         => 1,                  # The range of deviation (+/-) from baseline vooltage level in any given ROP. Used for Energy Feature
      },
   },
   Group_18_1A => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION            => {
         ATTRIBUTES                => {
            neMIMversion               => 'L.18.400', # Select counters with some null values
            nodeVersion                => '18.Q4',
         },
         COMMON                   => {
            ConsumedEnergyMeasurement => [1],
            EFuse                     => [1 .. 2],
            EnergyMeter               => [1 .. 2],
            FieldReplaceableUnit      => [1 .. 4],
         },
         METADATA                 => {
            MAX_POWER                 => 20,                 # Maximum transmission power of a node in watts. Used for Energy Feature
            POWER_VARIATION           => 5,                  # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
            RAT_TYPES                 => ['NR'],
            VOLTAGE_VARIATION         => 2,                  # The range of deviation (+/-) from baseline vooltage level in any given ROP. Used for Energy Feature
         },
      },
      Instances                => [510080 .. 510089],      
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

   my $ManagedElement_dir = "$node_dir/ManagedElement=1";
   mkpath($ManagedElement_dir) unless -d $ManagedElement_dir;

   # GNBCUCPFunction MOs
   for my $GNBCUCPFunction (@{ $parameters{NR}{GNBCUCPFunction} } ) {
      print "            GNBCUCPFunction             = $GNBCUCPFunction\n" if $debug;
      my $GNBCUCPFunction_dir = "$ManagedElement_dir/GNBCUCPFunction=$GNBCUCPFunction";
      mkpath($GNBCUCPFunction_dir) unless -d $GNBCUCPFunction_dir;
      # NRCellCU MOs
      for my $NRCellCU (@{ $parameters{NR}{NRCellCU} } ) {
         print "            NRCellCU             = $NRCellCU\n" if $debug;
         my $NRCellCU_dir = "$GNBCUCPFunction_dir/NRCellCU=$NRCellCU";
         mkpath($NRCellCU_dir) unless -d $NRCellCU_dir;
      }
   }

   # GNBDUFunction MOs
   for my $GNBDUFunction (@{ $parameters{NR}{GNBDUFunction} } ) {
      print "            GNBDUFunction             = $GNBDUFunction\n" if $debug;
      my $GNBDUFunction_dir = "$ManagedElement_dir/GNBDUFunction=$GNBDUFunction";
      mkpath($GNBDUFunction_dir) unless -d $GNBDUFunction_dir;
      # NRCellDU MOs
      for my $NRCellDU (@{ $parameters{NR}{NRCellDU} } ) {
         print "            NRCellDU             = $NRCellDU\n" if $debug;
         my $NRCellDU_dir = "$GNBDUFunction_dir/NRCellDU=$NRCellDU";
         mkpath($NRCellDU_dir) unless -d $NRCellDU_dir;
      }
   }



   # EnergyMeter MOs
   my $Equipment_dir = "$ManagedElement_dir/Equipment=1";

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
   my $NodeSupport_dir = "$ManagedElement_dir/NodeSupport=1";

   for my $ConsumedEnergyMeasurement (@{ $parameters{COMMON}{ConsumedEnergyMeasurement} } ) {
      print "            ConsumedEnergyMeasurement             = $ConsumedEnergyMeasurement\n" if $debug;
      my $ConsumedEnergyMeasurement_dir = "$NodeSupport_dir/ConsumedEnergyMeasurement=$ConsumedEnergyMeasurement";
      mkpath($ConsumedEnergyMeasurement_dir) unless -d $ConsumedEnergyMeasurement_dir;
   }

   # EquipmentSupportFunction MOs
   my $equipment_dir = "$ManagedElement_dir/EquipmentSupportFunction=1";

   for my $EnergyMeasurement (@{ $parameters{COMMON}{EnergyMeasurement} } ) {
      print "            EnergyMeasurement             = $EnergyMeasurement\n" if $debug;
      my $dir = "$equipment_dir/EnergyMeasurement=$node_index-$EnergyMeasurement";
      mkpath($dir) unless -d $dir;
   }
   

}

__END__
  create_MO_paths('NR', $node_dir, 'GNBCUCPFunction');


sub create_MO_paths() {
   my ($rat, $parent_dir, $child) = @_;
   for my $mo (@{ $parameters{$rat}{$child} } ) {
      print "$child = $mo\n" if $debug;
      my $child_dir = "$parent_dir/$child=$mo";
      mkpath($child_dir) unless -d $child_dir;
   }
   return 
}
