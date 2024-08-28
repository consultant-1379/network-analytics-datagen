#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy in a GSM radio network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# A BSC is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=bsc_2101/MeContext=bsc_2101
#
#TODO Need to rewrite this description
#
#
#
#### A UtranCell is represented by
####    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=bsc_2101/MeContext=bsc_2101/ManagedElement=1/bscFunction=1/UtranCell=2101-3
#
# An RBS is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=bsc_2101/MeContext=rbs_210101
#
# An EnergyMeasurement is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=bsc_2101/MeContext=rbs_210101/ManagedElement=1/EquipmentSupportFunction=1/EnergyMeasurement=210101-1
#
#
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
#    mkdir -p ManagedObjects/SubNetwork=ONRM_RootMo/MeContext=bsc_2101/ManagedElement=1/bscFunction=1/UtranCell=2101-3
#
# Note that the naming convention for cell ID is bsc_DIGITS-CELL, e.g. where bsc ID is bsc_2104, the first cell will be:
#    SubNetwork=ONRM_RootMo/SubNetwork=bsc_2104/MeContext=bsc_2104/ManagedElement=1/bscFunction=1/UtranCell=2104-1
# 
# To create a list of cells:
#    for i in {1..3}; do mkdir -p ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=bsc_2101/MeContext=bsc_2101/ManagedElement=1/bscFunction=1/UtranCell=2101-$i; done
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
# The third and fourth digits indicate the associated bsc in the case of an RBS node.
# Example: rbs_210101 is a G2 node connected to eniq_oss_1 and with associated bsc of bsc_2101
# Call the script with a -c argument to start with a new model structure.
# Note that all accumulated counters with history will be reset if -c is used.
#
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::DataGeneration;
use YAML::Tiny;
use File::Find; 
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
my $rbs_node_dir_template = "$root_dir/SubNetwork=<ROOT_MO>/SubNetwork=<BSC_NAME>/MeContext=<RBS_NAME>"; # <ROOT_MO>, <BSC_NAME> and <RBS_NAME> are placeholders to be modified later
my $bsc_node_dir_template = "$root_dir/SubNetwork=<ROOT_MO>/SubNetwork=<BSC_NAME>/MeContext=<BSC_NAME>"; # <ROOT_MO> and <RBS_NAME> are placeholders to be modified later

# Remove old paths they exist and if --clean argument given
clean_old_paths(root_dir => $root_dir, node_prefix => 'SubNetwork\=bsc_') if -d $root_dir and $clean;

my %bsc_model = (
   # These CONFIGURATION attributes are the defaults for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      COUNTER_CLASSES           => ['CELLBTSPS', 'CELLEIT2', 'CELLGPRS3', 'CELLQOSS', 'CELTCHF', 'CELTCHH', 'CLBCCHPS', 'CLDTMQOS', 'CLSDCCH', 'DOWNTIME', 'MOTG'],
      ROOT_DIR                  => $root_dir,
      cellBand                  => 'GSM800',
      cellLayer                 => 2,
      cellType                  => 1,
      daylightSavingsAdjust     => 1,
      fileFormatVersion         => '32.435 V8.0',
      GENERATION                => 'G1',
      GeranCells                => [1..15],              # The upper range value must be three times the number of RadioNodes supporting GSM (3 cells per node) for each BSC
      managedElementType        => 'BSC',
      MCC                       => 353,
      MNC                       => 87,
      MSC                       => 'msc_01',
      neMIMversion              => 'vV.4.3213',
      nodeVersion               => 'G16B',
      OSS_ID                    => 'eniq_oss_1',
      OUTPUT_DIR                => 'bsc-iog',
      BSC_PREFIX                => 'bsc_',
      REPORTING                 => 1,                    # 1 = Reporting, 0 = Not Reporting 
      ROOT_MO                   => 'ONRM_RootMo',
      ROP_LENGTH                => 900,
      siteRef                   => 'Athlone',
      sourceType                => 'AXE',
      SUBNETWORK                => 'GRAN',
      swVersion                 => 'CXP102051/21_R38ES',
      timeZone                  => '+0100',
      TOPOLOGY_DIR              => 'gran/topologyData/GranNetwork',
      TOPOLOGY_DIR_CELL         => 'gran/topologyData/CELL',
      TRX                       => 400,
      vendorName                => 'Ericsson',
   },
   Group_A => {
      CONFIGURATION => {
         GeranCells             => [1..30],              # The upper range value must be three times the number of RadioNodes supporting GSM (3 cells per node) for each BSC
      },
      Instances => [2101],      
   },
   Group_B => {
      CONFIGURATION => {
      },
      Instances => [2102 .. 2105],      
   },
);
   
print "bsc_model :\n", YAML::Tiny::Dump( \%bsc_model ) if $debug;

# Create BSC MOs
for my $grouping (sort keys %bsc_model) {
   next if $grouping eq 'CONFIGURATION';
   my %parameters = %{ $bsc_model{CONFIGURATION} };                                                         # set default values
   $parameters{$_} = $bsc_model{$grouping}{CONFIGURATION}{$_} for keys %{ $bsc_model{$grouping}{CONFIGURATION} }; # override with grouping parameters
   for my $node_index (@{ $bsc_model{$grouping}{Instances} } ) {
      create_bsc_managed_objects($node_index, %parameters);
   }
}

exit 0;

#
# Subroutines
#
#
sub create_bsc_managed_objects {
   my ($node_index, %parameters) = @_;

   my $bsc_name = "$parameters{BSC_PREFIX}$node_index";
   my $node_dir = $bsc_node_dir_template;             # take a copy of the template
   $node_dir    =~ s/<ROOT_MO>/$parameters{ROOT_MO}/; # substitute root MO
   $node_dir    =~ s/<BSC_NAME>/$bsc_name/g;          # substitute BSC name
   my $bsc_file = "$node_dir/$bsc_name.conf";

   $parameters{associatedBsc} = "SubNetwork=$parameters{ROOT_MO},SubNetwork=$parameters{SUBNETWORK},MeContext=$bsc_name";
   print "  Parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   print "bsc_name = $bsc_name\n" if $debug;
   print "node_dir = $node_dir\n" if $debug;
   print "bsc_file = $bsc_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   # Create the configuration file for each bsc
   my $yaml = YAML::Tiny->new( \%parameters );
   $yaml->write( $bsc_file );

   # BSSFunction MOs
   my $bsc_dir = "$node_dir/ManagedElement=1/BSSFunction=1";

   for my $GeranCell (@{ $parameters{GeranCells} } ) {
      print "            GeranCell             = $GeranCell\n" if $debug;
      my $dir = "$bsc_dir/GeranCell=$node_index-$GeranCell";
      for my $counter_class (@{ $parameters{COUNTER_CLASSES} } ) {
         my $counter_class_dir = "$dir/$counter_class=1";
         mkpath($counter_class_dir) unless -d $counter_class_dir;
      }
   }
}

__END__

=head
#
# RBS nodes not required for Energy Feature
# Leaving this code here in case some other RBS data required in a future project
#
my %rbs_model = (
   # These CONFIGURATION attributes are the defaults for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      BSC_PREFIX                => 'bsc_',
      EnergyMeasurement         => [1],
      fileFormatVersion         => '32.435 V10.0',
      GENERATION                => 'G2',
      managedElementType        => 'RadioNode',
      MAX_POWER                 => 40,                   # Maximum transmission power of a node in watts. Used for Energy Feature
      nodeVersion               => '16B',
      nodeType                  => 'BTS_B',
      OSS_ID                    => 'eniq_oss_1',
      OUTPUT_DIR                => 'RadioNode/COMMON',
      POWER_VARIATION           => 3,                    # The range of deviation (+/-) from baseline power level in any given ROP. Used for Energy Feature
      RBS_PREFIX                => 'rn_',
      REPORTING                 => 1,                    # 1 = Reporting, 0 = Not Reporting 
      ROOT_DIR                  => $root_dir,
      ROOT_MO                   => 'ONRM_RootMo',
      ROP_LENGTH                => 900,
      sourceType                => 'RBS6000',
      siteFDN                   => 'SubNetwork=ONRM_RootMo,Site=Athlone',
      swVersion                 => 'CXP9024418_4 R6AL',
      timeZone                  => '+0100',
      TOPOLOGY_DIR              => 'gsm/topologyData/RADIO',
      vendorName                => 'Ericsson',
      worldTimeZoneId           => 'Europe/Dublin',
   },
   Group_G2 => {
      CONFIGURATION => {
      },
      Instances                 => [210101 .. 210105, 210201 .. 210204, 210303 .. 210305, 210402 .. 210405, 210501 .. 210505], 
   },
   Group_G2_NotReporting => {
      CONFIGURATION => {
         REPORTING              => 0,                    # 1 = Reporting, 0 = Not Reporting 
      },
      Instances                 => [210301 .. 210302, 210401, 210205],      
   },
);

print "rbs_model :\n", YAML::Tiny::Dump( \%rbs_model ) if $debug;

# Create RBS MOs
for my $grouping (sort keys %rbs_model) {
   next if $grouping eq 'CONFIGURATION';
   my %parameters = %{ $rbs_model{CONFIGURATION} };                                                         # set default values
   $parameters{$_} = $rbs_model{$grouping}{CONFIGURATION}{$_} for keys %{ $rbs_model{$grouping}{CONFIGURATION} }; # override with grouping parameters
   for my $node_index (@{ $rbs_model{$grouping}{Instances} } ) {
      create_rbs_managed_objects($node_index, %parameters);
   }
}
=cut


=head
#
# RBS nodes not required for Energy Feature
# Leaving this code here in case some other RBS data required in a future project
#

sub create_rbs_managed_objects {
   my ($node_index, %parameters) = @_;

   my ($bsc_id) = $node_index =~ m/^(\d{4})/;
   my $bsc_name = "$parameters{BSC_PREFIX}$bsc_id";
   my $rbs_name = "$parameters{RBS_PREFIX}$node_index";
   my $node_dir = $rbs_node_dir_template;              # take a copy of the template
   $node_dir    =~ s/<ROOT_MO>/$parameters{ROOT_MO}/;  # substitute root MO
   $node_dir    =~ s/<RBS_NAME>/$rbs_name/;            # substitute RBS name
   $node_dir    =~ s/<BSC_NAME>/$bsc_name/;            # substitute bsc name
   my $rbs_file = "$node_dir/$rbs_name.conf";

   print "bsc_name = $bsc_name\n" if $debug;
   print "rbs_name = $rbs_name\n" if $debug;
   print "node_dir = $node_dir\n" if $debug;
   print "rbs_file = $rbs_file\n" if $debug;

   $parameters{associatedBsc} = "SubNetwork=$parameters{ROOT_MO},SubNetwork=$bsc_name,MeContext=$bsc_name";
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
}
=cut

