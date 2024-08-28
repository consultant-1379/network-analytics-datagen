#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::DataGeneration;
use File::Path;
use YAML::Tiny qw(Dump LoadFile);
use Carp;

my $usage = <<"USAGE";
 This script creates and populates the Site topology files with sample data.

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

 will create the topology files for all Sites.

USAGE

my $debug   = '';
my $help    = '';
my $verbose = '';  # default is off

GetOptions(
   'debug'   => \$debug,
   'help'    => \$help,
   'verbose' => \$verbose,
);

if ($help) {
   print "$usage\n\n\n";
   exit;
}

my %site_topology;
my $root_dir = '/eniq/home/dcuser/ManagedObjects';

for my $node_type (qw(ERBS RadioNode)) {
   my @node_config_files = get_configuration_info( root_dir => $root_dir, node_type => $node_type );
   my @geodata           = get_geodata($node_type);

   print "node_config_files :\n", Dump( \@node_config_files ) if $debug;

   for my $node_config_file (@node_config_files) {
      my ($node, $node_index) = $node_config_file =~ m{([^/]+?(\d{4})).conf};
      debug("node : $node");

      my $config   = LoadFile( $node_config_file );
      my $site_id  = ($node_type eq 'ERBS') ? "$config->{siteRef}$node_index"               : "$config->{ATTRIBUTES}{siteRef}$node_index";
      my $oss_id   = ($node_type eq 'ERBS') ? "$config->{OSS_ID}"                           : "$config->{METADATA}{OSS_ID}";
      my $timezone = ($node_type eq 'ERBS') ? "$config->{timeZone}"                         : "$config->{ATTRIBUTES}{timeZone}";
      my $fdn      = ($node_type eq 'ERBS') ? "SubNetwork=$config->{ROOT_MO},Site=$site_id" : "SubNetwork=$config->{METADATA}{ROOT_MO},Site=$config->{ATTRIBUTES}{siteRef}$node_index";

      $site_topology{$oss_id} .= site_topology( 
         altitude          => $geodata[$node_index]->{altitude},
         fdn               => $fdn,
         latitude          => $geodata[$node_index]->{latitude},
         longitude         => $geodata[$node_index]->{longitude},
         SiteId            => $site_id,
         timeZone          => $timezone,
         userLabel         => $site_id,
      );
   }

}

for my $oss_id ( keys %site_topology ) {
   my $topology_dir  = "/eniq/data/pmdata/$oss_id/lte/topologyData/Site";
   my $topology_file = "$topology_dir/sites.xml";

   mkpath( $topology_dir );   

   open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
   print {$TOPOLOGY_FH} topology_header();
   print {$TOPOLOGY_FH} $site_topology{$oss_id}; 
   print {$TOPOLOGY_FH} topology_footer(), "\n";
   close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
}

exit 0;

#
# Topology routines
#
sub topology_header {
   return <<'HEADER';
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE model PUBLIC "-//Ericsson NMS CIF CS//CS Filtered Export DTD//" "export.dtd">
<model>
HEADER
}

sub topology_footer {
   return <<'FOOTER';
</model>
FOOTER
}

sub site_topology {
   my %args = @_;

   return <<"SITE_TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ONRM" mimVersion="14.2.5">
    <attr name="altitude">$args{altitude}</attr>
    <attr name="longitude">$args{longitude}</attr>
    <attr name="timeZone">$args{timeZone}</attr>
    <attr name="latitude">$args{latitude}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="SiteId">$args{SiteId}</attr>
  </mo>
SITE_TOPOLOGY
}

#
# Geodata Handling
#
sub get_geodata {
   my ($node_type)  = shift;
   my $geodata_file = "/eniq/home/dcuser/counters/nodes/$node_type/geodata_locations.csv";
   my @geodata_list;

   open my $GEODATA_FH, '<', $geodata_file or croak "Cannot open file $geodata_file, $!";
   while (<$GEODATA_FH>) {
      next unless m/^\d/; # skip labels
      chomp;
      my %geodata;   
      ($geodata{altitude}, $geodata{latitude}, $geodata{longitude}) = split ',', $_; 
      push @geodata_list, \%geodata;
   }
   close $GEODATA_FH or croak "Cannot close file $geodata_file, $!";
   return @geodata_list;
}

