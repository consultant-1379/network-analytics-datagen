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
my %moids_for            = get_managed_objects(    root_dir         => $root_dir, node_counter_dir => $node_counter_dir );
my %counter_formulas_for = get_counter_formulas(   node_counter_dir => $node_counter_dir );

if ($debug) {
   print "node_config_for      :\n", Dump( \@node_config_files );
   print "moids_for            :\n", Dump( \%moids_for );
   print "\n";
}

for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config     = LoadFile( $node_config_file );

   next unless $config->{METADATA}{REPORTING}; # skip this node unless REPORTING is turned on
   
   my $fdn        = "SubNetwork=$config->{METADATA}{ROOT_MO},SubNetwork=$config->{METADATA}{SUBNETWORK},MeContext=$node";
   my $output_dir = "/eniq/data/pmdata/$config->{METADATA}{OSS_ID}/$config->{METADATA}{OUTPUT_DIR}/dir1/";

   print "config :\n", Dump( $config ) if $debug;   
 
   my $new_config;
 
   (my $file_date_time, $new_config->{cbt}, $new_config->{ts}, $new_config->{beginTime}, $new_config->{endTime} ) = get_time_info($config->{METADATA}{ROP_LENGTH}, $config->{ATTRIBUTES}{timeZone});

   $new_config->{fdn}         = $fdn; 
   $new_config->{dnPrefix}    = $fdn; 
   $new_config->{fsLocalDn}   = "MeContext=$node";
   $new_config->{elementType} = $config->{ATTRIBUTES}{managedElementType};
   $new_config->{meLocalDn}   = $new_config->{fsLocalDn};
   $new_config->{userLabel}   = $node;
   $new_config->{jobId}       = int(rand(100));
   $new_config->{ALLOW_UNDERSCORE_IN_COUNTER_NAMES} = 'True';
 
   # Need to map back new keys onto old format until all are converted to new format
   $new_config->{$_} = $config->{ATTRIBUTES}{$_} for keys %{ $config->{ATTRIBUTES} };
   $new_config->{$_} = $config->{METADATA}{$_}   for keys %{ $config->{METADATA} };
   
   print "new_config :\n", Dump( $new_config ) if $debug;

   set_power_configuration(max_power => $config->{METADATA}{MAX_POWER}, power_variation => $config->{METADATA}{POWER_VARIATION});
   set_voltage_configuration(max_voltage => $config->{METADATA}{MAX_VOLTAGE}, voltage_variation => $config->{METADATA}{VOLTAGE_VARIATION});
   reset_pmPowerConsumption(); # zero accumulated counter

   my $node_file = "$output_dir/A${file_date_time}_$new_config->{dnPrefix}_statsfile.xml";
   mkpath($output_dir);

   open $new_config->{FILE_HANDLE}, '>', "$node_file" or croak "Cannot open file $node_file, $!";      
   print { $new_config->{FILE_HANDLE} } file_header( $new_config );

   # Need to run EnergyMeter MOs first as these accumulate in ConsumedEnergy
   my @execution_order = ('EnergyMeter', grep !/EnergyMeter/, keys %moids_for);

   for my $mo_type (@execution_order) {
      next if $mo_type eq 'TwampTestSession';                   # TWAMP now handled in a separate file due to TCU TechPack using UTC

      my @node_mos = grep { /$fdn/ } @{ $moids_for{$mo_type} }; # find managed objects belonging to this node
      next unless @node_mos;                                    # skip if there are no managed objects with this MO type

      my $node_version   = $config->{ATTRIBUTES}{nodeVersion};
      my $ne_mim_version = $config->{ATTRIBUTES}{neMIMversion};

      debug("        mo_type : $mo_type");
      debug("   node_version : $node_version");
      debug(" ne_mim_version : $ne_mim_version");

      $new_config->{measInfoId} = $mo_type;
      $new_config->{COUNTERS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{COUNTERS};
      $new_config->{FORMULAS}   = $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{FORMULAS};

      next unless $new_config->{COUNTERS}; # skip if there are no counters for this MO type and version
      
      print_measurement_info_start( $new_config );

      for my $moid (@node_mos) {
         debug("         moid:  $moid");
         ($new_config->{measObjLdn}) = $moid =~ m/,(ManagedElement.*)/;
         print_measurement_values( $new_config );
      }

      print_measurement_info_end( $new_config );
   }      

   print { $new_config->{FILE_HANDLE} } file_footer( $new_config ), "\n";
   close $new_config->{FILE_HANDLE} or croak "Cannot close file $node_file, $!";   
}

exit 0;

