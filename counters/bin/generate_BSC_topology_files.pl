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
 This script creates and populates the GSM RAN topology files with sample data.

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

set_debug if $debug;

my $root_dir = '/eniq/home/dcuser/ManagedObjects';

#
# Handle BSC nodes and Cells
#
my @node_config_files = ( 
   get_configuration_info( root_dir => $root_dir, node_type => 'BSC' ),
);

my $first_node = 'True';

for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config              = LoadFile( $node_config_file );
   my $topology_dir        = "/eniq/data/pmdata/$config->{OSS_ID}/$config->{TOPOLOGY_DIR}";
   my $topology_dir_cells  = "/eniq/data/pmdata/$config->{OSS_ID}/$config->{TOPOLOGY_DIR_CELL}";
   my $bsc_id              = get_bsc_id($config->{associatedBsc});
   my $topology_file       = "$topology_dir/$config->{managedElementType}";
   my $topology_file_cells = "$topology_dir_cells/CELL";

   mkpath( $topology_dir );   
   mkpath( $topology_dir_cells );   

   debug("managedElementType : $config->{managedElementType}");
   debug("Configuration : ", $config);

   if ($first_node eq 'True') {
      if (-f $topology_file) {
         unlink $topology_file       or croak "Cannot delete file $topology_file, $!";
      };
      if (-f $topology_file_cells) {
         unlink $topology_file_cells or croak "Cannot delete file $topology_file_cells, $!";
      };
   }

   open my $TOPOLOGY_FH, '>>', $topology_file or croak "Cannot open file $topology_file, $!";
   print {$TOPOLOGY_FH} "nodeFDN|userLabel|nodeVersion|nodeType|sourceType|TRX|siteFDN\n" if $first_node eq 'True';    
   print {$TOPOLOGY_FH} "SubNetwork=$config->{ROOT_MO},SubNetwork=$config->{SUBNETWORK},ManagedElement=$node|$node|$config->{nodeVersion}|$config->{managedElementType}|$config->{sourceType}|$config->{TRX}|SubNetwork=$config->{ROOT_MO},Site=$config->{siteRef}\n";
   close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";

   open my $TOPOLOGY_CELL_FH, '>>', $topology_file_cells or croak "Cannot open file $topology_file_cells, $!";
   print {$TOPOLOGY_CELL_FH} "cellName|bscName|siteName|cellType|cellBand|cellLayer|mcc|mnc\n" if $first_node eq 'True';    

   my ($cell_prefix) = $node =~ m/(\d+)$/;
   for my $cell_id (@{ $config->{GeranCells} }) {
      print {$TOPOLOGY_CELL_FH} "$cell_prefix-$cell_id|$node|SubNetwork=$config->{ROOT_MO},Site=$config->{siteRef}|$config->{cellType}|$config->{cellBand}|$config->{cellLayer}|$config->{MCC}|$config->{MNC}\n";
   }

   close $TOPOLOGY_CELL_FH or croak "Cannot close file $topology_file_cells, $!";

   if ($first_node eq 'True') {
      $first_node = 'False';
   }
}

exit 0;



sub get_bsc_id {
   my $associatedBsc = shift;
   my ($bsc_id)      = $associatedBsc =~ m/=([^=]+)$/;
   return $bsc_id;
}

__END__

#
# Saving this BTS code for future use
#



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



my %node_dispatch_table = (
   RadioNode => \&rbs_topology,
   RBS       => \&rbs_topology,
);



my @node_config_files = ( 
   get_configuration_info( root_dir => $root_dir, node_type => 'bts' )
);

print "node_config_files :\n", Dump( \@node_config_files ) if $debug;

#
# Handle BTS nodes
#
for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config        = LoadFile( $node_config_file );
   my $topology_dir  = "/eniq/data/pmdata/$config->{OSS_ID}/$config->{TOPOLOGY_DIR}";
   my $bsc_id        = get_bsc_id($config->{associatedBsc});
   my $topology_file = "$topology_dir/SubNetwork_$config->{ROOT_MO}_SubNetwork_${bsc_id}_MeContext_${node}.xml";

   mkpath( $topology_dir );   

   debug("managedElementType : $config->{managedElementType}");
   debug("Configuration : ", $config);

   open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
   print {$TOPOLOGY_FH} topology_header();    
   print {$TOPOLOGY_FH} $node_dispatch_table{ $config->{managedElementType} }->( 
      CONFIG            => $config,
      ID                => $node,
      MeContextId       => $node,
      userLabel         => $node,
   );

   for my $cell_id (@{ $config->{GeranCells} }) {
      print {$TOPOLOGY_FH} GeranCell_topology( CELL_ID => $cell_id, CONFIG => $config);
   }

   print {$TOPOLOGY_FH} topology_footer(), "\n";
   close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
}



sub rbs_topology {
   my %args    = @_;
   my ($bscId) = $args{CONFIG}->{associatedBsc} =~ m/=([^=]+)$/;
   return <<"NODE_TOPOLOGY";
  <mo fdn="SubNetwork=$args{CONFIG}->{ROOT_MO},SubNetwork=$bscId,MeContext=$args{MeContextId}">
    <attr name="MeContextId">$args{MeContextId}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="siteRef">SubNetwork=$args{CONFIG}->{ROOT_MO},Site=$args{CONFIG}->{siteFDN}</attr>
    <attr name="nodeVersion">$args{CONFIG}->{nodeVersion}</attr>
    <attr name="managedElementType">$args{CONFIG}->{managedElementType}</attr>
  </mo>
NODE_TOPOLOGY
}




