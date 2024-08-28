#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy in a WCDMA radio network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# An RNC is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=rnc_2101/MeContext=rnc_2101
#
# A UtranCell is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=rnc_2101/MeContext=rnc_2101/ManagedElement=1/RNCFunction=1/UtranCell=2101-3
#
# An RBS is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=rnc_2101/MeContext=rbs_210101/ManagedElement=1/NodeBFunction=1
#
# An RbsLocalCell is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=rnc_2101/MeContext=rbs_210101/ManagedElement=1/NodeBFunction=1/RbsLocalCell=2101-1
#
# A configuration file is also generated for each MO where the PM counter generation script requires additional information to operate.
# For example, each RBS needs to state whether it is a G1 or G2 node, what node version it is, etc.
# In addition, the PM counter generation script uses the existence of this configuration file to determine whether or not to generate counters for this node.
# Removing this file will turn off counter generation for that node.
# After this script has generated the configuration file, it may be manually modified to alter any parameter, 
# e.g. to change the OSS_ID from eniq_oss_1 to eniq_oss_3 for testing purposes.
#
# Note however that rerunning this script will overwrite any locally modified versions.
#
# New managed objects may also be created after execution of this script by simply creating a file path to model the MO required.
# For example to add a new cell just execute the following command:
#    mkdir -p ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=rnc_2101/ManagedElement=1/RNCFunction=1/UtranCell=2101-3
#
# Note that the naming convention for cell ID is RNC_DIGITS-CELL, e.g. where RNC ID is rnc_2104, the first cell will be:
#    SubNetwork=ONRM_RootMo/SubNetwork=rnc_2104/MeContext=rnc_2104/ManagedElement=1/RNCFunction=1/UtranCell=2104-1
# 
# To create a list of cells:
#    for i in {1..3}; do mkdir -p ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=rnc_2101/MeContext=rnc_2101/ManagedElement=1/RNCFunction=1/UtranCell=2101-$i; done
#
# To aid identification during test, the numbering convention for nodes is that:
#   G1 nodes are in the range 110000-130099
#                  in OSS_1 : 110000-110099
#                  in OSS_2 : 120000-120099
#                  in OSS_3 : 130000-130099
#
#   G2 nodes are in the range 210000-230099 
#                  in OSS_1 : 210000-210099
#                  in OSS_2 : 220000-220099
#                  in OSS_3 : 230000-230099
#
# The second digit indicates the OSS.
# The third and fourth digits indicate the associated RNC in the case of an RBS node.
# Example: rbs_210101 is a G2 node connected to eniq_oss_1 and with associated RNC of rnc_2101
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

my $root_dir              = '/eniq/home/dcuser/ManagedObjects';

# Remove old paths they exist and if --clean argument given
clean_old_paths(root_dir => $root_dir, node_prefix => 'SubNetwork\=rnc_') if -d $root_dir and $clean;

my %rnc_model = (
   # These CONFIGURATION attributes are the defaults for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ROOT_DIR                  => $root_dir,
      daylightSavingsAdjust     => 1,
      fileFormatVersion         => '32.435 V8.0',
      Eul                       => [],
      GsmRelation               => [],
      Hsdsch                    => [],
      GENERATION                => 'G1',
      managedElementType        => 'RNC',
      MCC                       => 353,
      MNC                       => 87,
      MSC                       => 'msc_01',
      neMIMversion              => 'vU.4.3213',
      nodeVersion               => 'W16B',
      OSS_ID                    => 'eniq_oss_1',
      OUTPUT_DIR                => 'rnc',
      REPORTING                 => 1,                    # 1 = Reporting, 0 = Not Reporting 
      RNC_PREFIX                => 'rnc_',
      ROOT_MO                   => 'ONRM_RootMo',
      ROP_LENGTH                => 900,
      siteRef                   => 'Athlone',
      SUBNETWORK                => 'WRAN',
      swVersion                 => 'CXP102051/21_R38ES',
      timeZone                  => '-0100',
      TOPOLOGY_DIR              => 'utran/topologyData/RNC',
      UtranCell                 => [1..15],              # The upper range value must be three times the number of RadioNodes supporting WCDMA (3 cells per node) 
      vendorName                => 'Ericsson',
   },
   Group_G1 => {
      CONFIGURATION => {
      },
      Instances => [1101 .. 1105],      
   },
   Group_G1_17B => {
      CONFIGURATION => {
         Eul                    => [1],
         GsmRelation            => [1 .. 8],
         Hsdsch                 => [1],
         neMIMversion           => 'vV.4.3213',
         nodeVersion            => 'W17B',
       },
      Instances => [1201 .. 1205],      
   },
   Group_G2_A => {
      CONFIGURATION => {
         UtranCell              => [1..30],              # The upper range value must be three times the number of RadioNodes supporting GSM (3 cells per node) for each RNC
      },
      Instances => [2101],      
   },
   Group_G2_B => {
      CONFIGURATION => {
      },
      Instances => [2102 .. 2105],      
   },
);
   
print "rnc_model :\n", YAML::Tiny::Dump( \%rnc_model ) if $debug;

my %rbs_model = (
   # These CONFIGURATION attributes are the defaults for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      daylightSavingsAdjust     => 1,
      EnergyMeasurement         => [1],
      fileFormatVersion         => '32.435 V8.0',
      GENERATION                => 'G1',
      HsDschResources           => [],
      managedElementType        => 'RBS',
      MAX_POWER                 => 40,             # Maximum transmission power of a node in watts. Used for Energy Feature
      MCC                       => 353,
      MNC                       => 87,
      neMIMversion              => 'vU.4.270',
      nodeVersion               => 'W16B',
      OSS_ID                    => 'eniq_oss_1',
      OUTPUT_DIR                => 'rbs',
      POWER_VARIATION           => 3,              # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
      RbsLocalCell              => [],
      RBS_PREFIX                => 'rbs_',
      REPORTING                 => 1,              # 1 = Reporting, 0 = Not Reporting 
      RNC_PREFIX                => 'rnc_',
      ROOT_DIR                  => $root_dir,
      ROOT_MO                   => 'ONRM_RootMo',
      ROP_LENGTH                => 900,
      siteRef                   => 'Athlone',
      SUBNETWORK                => 'WRAN',
      swVersion                 => 'CXP102051/21_R38ES',
      timeZone                  => '+0000',
      TOPOLOGY_DIR              => 'utran/topologyData/RBS',
      vendorName                => 'Ericsson',
      worldTimeZoneId           => 'Europe/Dublin',
   },
   Group_G1 => {
      CONFIGURATION => {
      },
      Instances                 => [110101 .. 110105, 110201 .. 110205, 110301 .. 110305, 110401 .. 110402, 110501 .. 110504], 
   },
   Group_G1_NotReporting => {
      CONFIGURATION => {
         REPORTING              => 0,                    # 1 = Reporting, 0 = Not Reporting 
      },
      Instances                 => [110403 .. 110405, 110505],      
   },
   Group_G1_17B => {
      CONFIGURATION => {
         HsDschResources        => [1],
         neMIMversion           => 'vV.4.270',
         nodeVersion            => 'W17B',
         RbsLocalCell           => [1 .. 3],
      },
      Instances                 => [120101 .. 120105, 120201 .. 120205, 120301 .. 120305, 120401 .. 120402, 120501 .. 120504], 
   },
);

print "rbs_model :\n", YAML::Tiny::Dump( \%rbs_model ) if $debug;

# Create RNC MOs
for my $grouping (sort keys %rnc_model) {
   next if $grouping eq 'CONFIGURATION';
   my %parameters = %{ $rnc_model{CONFIGURATION} };                                                         # set default values
   $parameters{$_} = $rnc_model{$grouping}{CONFIGURATION}{$_} for keys %{ $rnc_model{$grouping}{CONFIGURATION} }; # override with grouping parameters
   for my $node_index (@{ $rnc_model{$grouping}{Instances} } ) {
      create_rnc_managed_objects($node_index, %parameters);
   }
}

# Create RBS MOs
for my $grouping (sort keys %rbs_model) {
   next if $grouping eq 'CONFIGURATION';
   my %parameters = %{ $rbs_model{CONFIGURATION} };                                                         # set default values
   $parameters{$_} = $rbs_model{$grouping}{CONFIGURATION}{$_} for keys %{ $rbs_model{$grouping}{CONFIGURATION} }; # override with grouping parameters
   for my $node_index (@{ $rbs_model{$grouping}{Instances} } ) {
      create_rbs_managed_objects($node_index, %parameters);
   }
}

exit 0;

#
# Subroutines
#
#
sub create_rbs_managed_objects {
   my ($node_index, %parameters) = @_;

   my ($rnc_id) = $node_index =~ m/^(\d{4})/;
   my $rnc_name = "$parameters{RNC_PREFIX}$rnc_id";
   my $rbs_name = "$parameters{RBS_PREFIX}$node_index";
   my $node_dir = "$root_dir/SubNetwork=$parameters{ROOT_MO}/SubNetwork=$rnc_name/MeContext=$rbs_name";
   my $rbs_file = "$node_dir/$rbs_name.conf";

   print "rnc_name = $rnc_name\n" if $debug;
   print "rbs_name = $rbs_name\n" if $debug;
   print "node_dir = $node_dir\n" if $debug;
   print "rbs_file = $rbs_file\n" if $debug;

   $parameters{associatedRnc} = "SubNetwork=$parameters{ROOT_MO},SubNetwork=$rnc_name,MeContext=$rnc_name";
   print "  Parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   mkpath($node_dir) unless -d $node_dir;

   # Create the configuration file for each RBS
   my $yaml = YAML::Tiny->new( \%parameters );
   $yaml->write( $rbs_file );

   # EquipmentSupportFunction MOs
   my $equipment_dir = "$node_dir/ManagedElement=1/EquipmentSupportFunction=1";

   for my $EnergyMeasurement (@{ $parameters{EnergyMeasurement} } ) {
      print "            EnergyMeasurement             = $EnergyMeasurement\n" if $debug;
      my $dir = "$equipment_dir/EnergyMeasurement=$node_index-$EnergyMeasurement";
      mkpath($dir) unless -d $dir;
   }

   # NodeBFunction MOs
   my $nodeb_dir = "$node_dir/ManagedElement=1/NodeBFunction=1";

   for my $RbsLocalCell (@{ $parameters{RbsLocalCell} } ) {
      print "            RbsLocalCell             = $RbsLocalCell\n" if $debug;
      my $dir = "$nodeb_dir/RbsLocalCell=$RbsLocalCell";
      mkpath($dir) unless -d $dir;

      for my $HsDschResources (@{ $parameters{HsDschResources} } ) {
         print "            HsDschResources             = $HsDschResources\n" if $debug;
         my $hs_dir = "$dir/HsDschResources=$HsDschResources";
         mkpath($hs_dir) unless -d $hs_dir;
      }

   }

}

sub create_rnc_managed_objects {
   my ($node_index, %parameters) = @_;

   my $rnc_name               = "$parameters{RNC_PREFIX}$node_index";
   $parameters{associatedRnc} = "SubNetwork=$parameters{ROOT_MO},SubNetwork=$rnc_name,MeContext=$rnc_name";
   my $rnc_path               = $parameters{associatedRnc};
   $rnc_path                  =~ s{,}{/}g;
   my $node_dir               = "$root_dir/$rnc_path"; 
   my $rnc_file               = "$node_dir/$rnc_name.conf";

   print "  Parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   print "rnc_name = $rnc_name\n" if $debug;
   print "node_dir = $node_dir\n" if $debug;
   print "rnc_file = $rnc_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   # Create the configuration file for each RNC
   my $yaml = YAML::Tiny->new( \%parameters );
   $yaml->write( $rnc_file );

   # RncFunction MOs
   my $rnc_dir = "$node_dir/ManagedElement=1/RncFunction=1";

   # UtranCell MOs
   for my $UtranCell (@{ $parameters{UtranCell} } ) {
      print "            UtranCell             = $UtranCell\n" if $debug;
      my $dir = "$rnc_dir/UtranCell=$node_index-$UtranCell";
      mkpath($dir) unless -d $dir;


      # GsmRelation MOs
      for my $GsmRelation (@{ $parameters{GsmRelation} } ) {
         print "            GsmRelation             = $GsmRelation\n" if $debug;
         my $dir = "$rnc_dir/UtranCell=$node_index-$UtranCell/GsmRelation=$GsmRelation";
         mkpath($dir) unless -d $dir;
      }

      # Hsdsch MOs
      for my $Hsdsch (@{ $parameters{Hsdsch} } ) {
         print "            Hsdsch             = $Hsdsch\n" if $debug;
         my $dir = "$rnc_dir/UtranCell=$node_index-$UtranCell/Hsdsch=$Hsdsch";
         mkpath($dir) unless -d $dir;

         # Eul MOs
         for my $Eul (@{ $parameters{Eul} } ) {
            print "            Eul             = $Eul\n" if $debug;
            my $eul_dir = "$dir/Eul=$Eul";
            mkpath($eul_dir) unless -d $eul_dir;
         }
      }

   }
}


