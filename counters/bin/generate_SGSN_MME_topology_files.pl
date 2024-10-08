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
 This script creates and populates the SGSN MME topology files with sample data.

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

 will create the topology files for all NEs.

USAGE

my $debug      	= '';
my $help       	= '';
my $verbose    	= '';  # default is off

GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
);

set_debug if $debug;

if ($help) {
   print "$usage\n\n\n";
   exit;
}

my ($node_type)       = $0 =~ m/generate_(\w+)_topology_files/; # extract node type from calling script name
my $root_dir          = '/eniq/home/dcuser/ManagedObjects';
my $node_counter_dir  = "/eniq/home/dcuser/counters/nodes/$node_type/Counters";
my @node_config_files = get_configuration_info( root_dir => $root_dir, node_type => $node_type );
my %moids_for         = get_managed_objects( root_dir => $root_dir, node_counter_dir => $node_counter_dir );

print "node_config_files :\n", Dump( \@node_config_files ) if $debug;


for my $node_config_file (@node_config_files) {
#   my ($node) = $node_config_file =~ m{([^/]+).conf};
   my ($node, $node_index) = $node_config_file =~ m{([^/]+?(\d{2})).conf};
   debug("node : $node");

   my $config        = LoadFile( $node_config_file );
   my $fdn           = "SubNetwork=$config->{METADATA}{ROOT_MO},SubNetwork=$config->{METADATA}{SUBNETWORK},ManagedElement=$node";

      my $topology_dir  = "/eniq/data/pmdata/$config->{METADATA}{OSS_ID}/$config->{METADATA}{TOPOLOGY_DIR}";
      my $topology_file = "$topology_dir/${fdn}.xml";

      mkpath( $topology_dir );   

      open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
      print {$TOPOLOGY_FH} topology_header();    
      print {$TOPOLOGY_FH} topology( 
                                    $fdn, 
                                    $node, 
                                    "SubNetwork=$config->{METADATA}{ROOT_MO},Site=$config->{ATTRIBUTES}{siteRef}$node_index", 
                                    $config->{ATTRIBUTES}{nodeVersion},
                                    $config->{ATTRIBUTES}{managedElementType},
                                   );

      
      print {$TOPOLOGY_FH} topology_footer(), "\n";
      close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
   
}

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

sub topology {
   my ($fdn, $user_label, $site, $node_version, $managed_element_type ) = @_;
   my $me_type;
   my @me_types = split',', $managed_element_type;
   my $me_count =  $#me_types + 1;
   if (@me_types) {
      $me_type .= "        <seq count=\"$me_count\">\n";
      $me_type .= "          <item>$_</item>\n" for @me_types;
      $me_type .= "        </seq>";
   } else {
      $me_type = <<"ME_TYPE"
        <seq count="1">
          <item>$managed_element_type</item>
        </seq>
ME_TYPE
   }

   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="5.0">
      <attr name="userLabel">$user_label</attr>
      <attr name="nodeVersion">$node_version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="managedElementType">
$me_type
      </attr>
   </mo>
NE_TOPOLOGY
}


