#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use Carp;
use Getopt::Long;
use YAML::Tiny qw(Dump LoadFile);
use ENIQ::DataGeneration;
use File::Path;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]

    -d, --debug
                output debug information 
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 

 Example:
        $0 

 will create the ROP files for all counters in the input files.

USAGE

my $debug      	= '';
my $help       	= '';
my $verbose    	= ''; # default is off

GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
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
#   print "counter_formulas_for :\n", Dump( \%counter_formulas_for ) if $debug;
   print "\n";
}

for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config = LoadFile( $node_config_file );

   next unless $config->{REPORTING}; # skip this node unless REPORTING is turned on
   
   my $fdn = "SubNetwork=$config->{ROOT_MO},SubNetwork=$config->{SUBNETWORK},MeContext=$node";

   (my $file_date_time, $config->{cbt}, $config->{ts}, $config->{beginTime}, $config->{endTime} ) = get_time_info($config->{ROP_LENGTH}, $config->{timeZone});

   $config->{fdn}         = $fdn; 
   $config->{dnPrefix}    = $fdn; 
   $config->{fsLocalDn}   = "MeContext=$node";
   $config->{elementType} = $config->{managedElementType};
   $config->{meLocalDn}   = $config->{fsLocalDn};
   $config->{userLabel}   = $node;
   $config->{jobId}       = int(rand(100));
   print "config :\n", Dump( $config ) if $debug;

   set_power_configuration(max_power => $config->{MAX_POWER}, power_variation => $config->{POWER_VARIATION});
   set_voltage_configuration(max_voltage => $config->{MAX_VOLTAGE}, voltage_variation => $config->{VOLTAGE_VARIATION});
   reset_pmPowerConsumption(); # zero accumulated counter

   #
   # Handle ENIQ Statistics data
   #
   my $stats_output_dir = "/eniq/data/pmdata/$config->{OSS_ID}/$config->{OUTPUT_DIR}/dir1/";
   my $stats_file       = "$stats_output_dir/A${file_date_time}_$config->{dnPrefix}_statsfile.xml";
   mkpath($stats_output_dir);

   open $config->{FILE_HANDLE}, '>', "$stats_file" or croak "Cannot open file $stats_file, $!";      
   print { $config->{FILE_HANDLE} } file_header( $config );

   # Need to run EnergyMeter MOs first as these accumulate in ConsumedEnergy
   my @execution_order = ('EnergyMeter', grep !/EnergyMeter/, keys %moids_for);

   for my $mo_type (@execution_order) {
      my @node_mos = grep { /$fdn/ } @{ $moids_for{$mo_type} }; # find managed objects belonging to this node
      next unless @node_mos;                                    # skip if there are no managed objects with this MO type

      my $node_version   = $config->{nodeVersion};
      my $ne_mim_version = $config->{neMIMversion};

      debug("        mo_type : $mo_type");
      debug("   node_version : $node_version");
      debug(" ne_mim_version : $ne_mim_version");

      $config->{measInfoId} = $mo_type;
      $config->{COUNTERS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{COUNTERS};
      $config->{FORMULAS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{FORMULAS};

      next unless $config->{COUNTERS}; # skip if there are no counters for this MO type and version
      
      print_measurement_info_start( $config );

      for my $moid (@node_mos) {
         debug("         moid:  $moid");
         ($config->{measObjLdn}) = $moid =~ m/,(ManagedElement.*)/;
         print_measurement_values( $config );
      }

      print_measurement_info_end( $config );
   }      

   print { $config->{FILE_HANDLE} } file_footer( $config ), "\n";
   close $config->{FILE_HANDLE} or croak "Cannot close file $stats_file, $!";  

   #
   # Handle ENIQ Events data
   #
   my $events_output_dir = "/eniq/data/pmdata/$config->{EBS_EVENTS_ID}/$config->{EBS_OUTPUT_DIR}/$config->{EBS_OSS_ID}/dir1/";
   my $events_file       = "$events_output_dir/A${file_date_time}_$config->{dnPrefix}_statsfile.xml";
   mkpath($events_output_dir);

   open $config->{FILE_HANDLE}, '>', "$events_file" or croak "Cannot open file $events_file, $!";      
   print { $config->{FILE_HANDLE} } file_header( $config );

   for my $mo_type (sort keys %moids_for) {     
      my $node_version   = $config->{nodeVersion};
      my $ne_mim_version = $config->{neMIMversion};

      debug("        mo_type : $mo_type");
      debug("   node_version : $node_version");
      debug(" ne_mim_version : $ne_mim_version");

      next unless $mo_type =~ /EUtranCellFDD|EUtranCellTDD/; # Only EUtranCellFDD and EUtranCellTDD counters needed for ENIQ Events

      debug(" EBS counters :  @{ $config->{EBS_COUNTERS} }");
      my %counters;
      $counters{$_}         = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{COUNTERS}{$_} for @{ $config->{EBS_COUNTERS} };
      $config->{COUNTERS}   = \%counters;
      $config->{measInfoId} = $mo_type;
      $config->{FORMULAS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{FORMULAS};
      #      print "EBS config :  " . Dump( $config->{COUNTERS} );

      my @node_mos = grep { /$fdn/ } @{ $moids_for{$mo_type} }; # find managed objects belonging to this node

      next unless @node_mos; # skip if there are no managed objects with this MO type

      print_measurement_info_start( $config );

      for my $moid (@node_mos) {
         debug("         moid:  $moid");
         ($config->{measObjLdn}) = $moid =~ m/,(ManagedElement.*)/;
         print_measurement_values( $config );
      }

      print_measurement_info_end( $config );
   }      

   print { $config->{FILE_HANDLE} } file_footer( $config ), "\n";
   close $config->{FILE_HANDLE} or croak "Cannot close file $events_file, $!";  
}

exit 0;

