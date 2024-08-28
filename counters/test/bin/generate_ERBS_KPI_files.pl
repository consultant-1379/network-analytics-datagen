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
 This script creates and populates the computed values files with sample data.

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

 will create the computed values files for all KPIs in the input files.

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

my ($node_type)          = $0 =~ m/generate_(\w+)_KPI_files/; # extract node type from calling script name
my $root_dir             = '/eniq/home/dcuser/ManagedObjects';
my $node_counter_dir     = "/eniq/home/dcuser/counters/nodes/$node_type/Counters";
my @node_config_files    = get_configuration_info( root_dir         => $root_dir, node_type        => $node_type );
my %moids_for            =    get_managed_objects( root_dir         => $root_dir, node_counter_dir => $node_counter_dir );
#my %counter_formulas_for =   get_counter_formulas( node_counter_dir => $node_counter_dir );

if ($debug) {
   print "node_config_for      :\n", Dump( \@node_config_files );
   print "moids_for            :\n", Dump( \%moids_for );
#   print "counter_formulas_for :\n", Dump( \%counter_formulas_for ) if $debug;
   print "\n";
}

#my $file_id = '10000000000'; #sprintf "%013d", int(rand(10000000000));
#my $today = `date '+%Y-%m-%d'`;
#chomp $today;

#print "file_id = $file_id\n";
#print "today = $today\n";

#my $stats_output_dir = "/eniq/data/etldata_/00/dc_cv_erbs_eutrancell/raw/";
my $stats_output_dir = "/eniq/home/dcuser/dc_cv_erbs_eutrancell";
my $stats_file       = "$stats_output_dir/DC_CV_ERBS_EUTRANCELL.txt";
mkpath($stats_output_dir);

open my $FILE_HANDLE, '>', "$stats_file" or croak "Cannot open file $stats_file, $!";      

for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config = LoadFile( $node_config_file );

   next unless $config->{REPORTING}; # skip this node unless REPORTING is turned on
   
   my $fdn = "SubNetwork=$config->{ROOT_MO},SubNetwork=$config->{SUBNETWORK},MeContext=$node";

   (my $file_date_time, $config->{cbt}, $config->{ts}, $config->{beginTime}, $config->{endTime} ) = get_time_info($config->{ROP_LENGTH}, $config->{timeZone});

   $config->{dnPrefix}    = $fdn; 
   $config->{fsLocalDn}   = "MeContext=$node";
   $config->{elementType} = $config->{managedElementType};
   $config->{meLocalDn}   = $config->{fsLocalDn};
   $config->{userLabel}   = $node;
   $config->{jobId}       = int(rand(100));
   print "config :\n", Dump( $config ) if $debug;

   my ($date, $year, $month, $day, $hour, $minute) = $config->{beginTime} =~ m/((\d{4})-(\d{2})-(\d{2}))T(\d{2}):(\d{2})/;

   for my $mo_type (sort keys %moids_for) {

      next unless $mo_type =~ m/EUtranCellFDD|EUtranCellTDD/;
      
      my @node_mos = grep { /$fdn/ } @{ $moids_for{$mo_type} }; # find managed objects belonging to this node
      next unless @node_mos;                                    # skip if there are no managed objects with this MO type

      my $node_version   = $config->{nodeVersion};
      my $ne_mim_version = $config->{neMIMversion};

      debug("        mo_type : $mo_type");
      debug("   node_version : $node_version");
      debug(" ne_mim_version : $ne_mim_version");

      $config->{measInfoId} = $mo_type;
 

      my $datetime = "$date $hour:$minute:00";
      my ($timelevel, $session_id, $batch_id, $period_duration, $rowstatus, $dc_release, $dc_source, $dc_timezone, $dc_suspectflag) = ('15MIN', 1234, 56, 15, '', '', '', '', 0);
     
      for my $moid (@node_mos) {
         debug("         moid:  $moid");
         $config->{measObjLdn} = $moid;

#         my $row = join "\t", ($node, $moid, $config->{OSS_ID}, $measure, $date, $year, $month, $day, $hour, $datetime, $minute, $timelevel, $session_id, $batch_id, $period_duration, $rowstatus, $dc_release, $dc_source, $dc_timezone, $dc_suspectflag, $datetime, $value);
         for my $measure (1 .. 4) {
            my $value    = rand(100);
            my $row = join "\t", ($fdn, $moid, $config->{OSS_ID}, $measure, $value, 'LOADED', $datetime, $datetime);
            print { $FILE_HANDLE } "$row\n";
         }
      }
   }      
}

close $FILE_HANDLE or croak "Cannot close file $stats_file, $!";  

