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
 This script creates and populates the WCDMA RAN topology files with sample data.

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

my $root_dir          = '/eniq/home/dcuser/ManagedObjects';
my @node_config_files = ( 
   get_configuration_info( root_dir => $root_dir, node_type => 'RNC' ),
   get_configuration_info( root_dir => $root_dir, node_type => 'RBS' ) 
);

print "node_config_files :\n", Dump( \@node_config_files ) if $debug;

my %node_dispatch_table = (
   RBS       => \&rbs_topology,
   RNC       => \&rnc_topology,
);

for my $node_config_file (@node_config_files) {
   my ($node) = $node_config_file =~ m{([^/]+).conf};
   debug("node : $node");

   my $config        = LoadFile( $node_config_file );
   my $topology_dir  = "/eniq/data/pmdata/$config->{OSS_ID}/$config->{TOPOLOGY_DIR}";
   my $rnc_id        = get_rnc_id($config->{associatedRnc});
   my $topology_file = "$topology_dir/SubNetwork_$config->{ROOT_MO}_SubNetwork_${rnc_id}_MeContext_${node}.xml";
   my $current_time  = get_current_time( timezone => $config->{timeZone} );

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

   # Only RNCs will have UtranCells
   for my $cell_id (@{ $config->{UtranCell} }) {
      print {$TOPOLOGY_FH} UtranCell_topology( CELL_ID => $cell_id, CONFIG => $config);
   }

   # Only RNCs will have RbsLocalCells
   for my $rbs_local_cell_id (@{ $config->{RbsLocalCell} }) {
      print {$TOPOLOGY_FH} RbsLocalCell_topology( MeContextId => $node, RbsLocalCell_ID => $rbs_local_cell_id, CONFIG => $config);
   }

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

sub rnc_topology {
   my %args = @_;

   return <<"NODE_TOPOLOGY";
  <mo fdn="$args{CONFIG}->{associatedRnc}">
    <attr name="MeContextId">$args{MeContextId}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="neMIMversion">$args{CONFIG}->{neMIMversion}</attr>
    <attr name="swVersion">$args{CONFIG}->{swVersion}</attr>
    <attr name="siteRef">SubNetwork=$args{CONFIG}->{ROOT_MO},Site=$args{CONFIG}->{siteRef}</attr>
    <attr name="nodeVersion">$args{CONFIG}->{nodeVersion}</attr>
    <attr name="MNC">$args{CONFIG}->{MNC}</attr>
    <attr name="MCC">$args{CONFIG}->{MCC}</attr>
    <attr name="MSC">$args{CONFIG}->{MSC}</attr>
    <attr name="managedElementType">$args{CONFIG}->{managedElementType}</attr>
  </mo>
  <mo fdn="$args{CONFIG}->{associatedRnc},ManagedElement=1,RncFunction=1" mimName="RNC_NODE_MODEL">
    <attr name="rncId">$args{ID}</attr>
  </mo>
NODE_TOPOLOGY
}

sub rbs_topology {
   my %args    = @_;
   my ($rncId) = $args{CONFIG}->{associatedRnc} =~ m/=([^=]+)$/;
   return <<"NODE_TOPOLOGY";
  <mo fdn="SubNetwork=$args{CONFIG}->{ROOT_MO},SubNetwork=$rncId,MeContext=$args{MeContextId}">
    <attr name="MeContextId">$args{MeContextId}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="neMIMversion">$args{CONFIG}->{neMIMversion}</attr>
    <attr name="swVersion">$args{CONFIG}->{swVersion}</attr>
    <attr name="siteRef">SubNetwork=$args{CONFIG}->{ROOT_MO},Site=$args{CONFIG}->{siteRef}</attr>
    <attr name="nodeVersion">$args{CONFIG}->{nodeVersion}</attr>
    <attr name="managedElementType">$args{CONFIG}->{managedElementType}</attr>
    <attr name="MNC">$args{CONFIG}->{MNC}</attr>
    <attr name="MCC">$args{CONFIG}->{MCC}</attr>
    <attr name="associatedRnc">$args{CONFIG}->{associatedRnc}</attr>
    <attr name="rncId">$rncId</attr>
  </mo>
NODE_TOPOLOGY
}

sub UtranCell_topology {
   my %args = @_;

   my ($rncId)   = $args{CONFIG}->{associatedRnc} =~ m/_([^_]+)$/;
   my $rbs_index = sprintf '%02d', int( ($args{CELL_ID} - 1)/3) + 1;
   my $rbs_id    = substr($rncId, 0, 1) eq '2' ? 'rn' : 'rbs';
   $rbs_id      .= "_$rncId$rbs_index"; # G2 nodes use rn_ as prefix, G1 use rbs_

return <<"CELL_TOPOLOGY";
  <mo fdn="$args{CONFIG}->{associatedRnc},ManagedElement=1,RncFunction=1,UtranCell=$args{CELL_ID}" mimName="RNC_NODE_MODEL">
    <attr name="MNC">$args{CONFIG}->{MNC}</attr>
    <attr name="MCC">$args{CONFIG}->{MCC}</attr>
    <attr name="maximumTransmissionPower">400</attr>
    <attr name="dlCodeAdm">80</attr>
    <attr name="UtranCellId">$rncId-$args{CELL_ID}</attr>
    <attr name="rbsId">$rbs_id</attr>
    <attr name="SAC">1</attr>
    <attr name="UARFCNUL">1</attr>
    <attr name="primaryCpichPower">300</attr>
    <attr name="userLabel">$rncId-$args{CELL_ID}</attr>
    <attr name="LAC">397</attr>
    <attr name="absPrioCellRes">
       <struct>
          <attr name="sPrioritySearch1">16</attr>
          <attr name="sPrioritySearch2">6</attr>
          <attr name="measIndFach">0</attr>
          <attr name="cellReselectionPriority">3</attr>
          <attr name="threshServingLow">16</attr>
       </struct>
    </attr>
    <attr name="supportedCellType">0</attr>
    <attr name="hsdpaUsersAdm">10</attr>
    <attr name="UARFCNDL">23</attr>
    <attr name="poolRedundancy">0</attr>
    <attr name="pwrAdm">75</attr>
    <attr name="tCell">1</attr>
    <attr name="localCellId">$args{CELL_ID}</attr>
    <attr name="utranCellIubLink">$args{CONFIG}->{associatedRnc},ManagedElement=1,RncFunction=1,IubLink=Iub-1175</attr>
    <attr name="SCRAMBLINGCODE">1</attr>
    <attr name="eulServingCellUsersAdm">32</attr>
    <attr name="RAC">1</attr>
   </mo>
CELL_TOPOLOGY
}

sub get_rnc_id {
   my $associatedRnc = shift;
   my ($rnc_id)      = $associatedRnc =~ m/=([^=]+)$/;
   return $rnc_id;
}

sub RbsLocalCell_topology {
   my %args    = @_;
   my ($rncId) = $args{CONFIG}->{associatedRnc} =~ m/=([^=]+)$/;
   return <<"RBSLOCALCELL_TOPOLOGY";
  <mo fdn="SubNetwork=$args{CONFIG}->{ROOT_MO},SubNetwork=$rncId,MeContext=$args{MeContextId},ManagedElement=1,NodeBFunction=1,RbsLocalCell=$args{RbsLocalCell_ID}">
    <attr name="localCellId">$args{RbsLocalCell_ID}</attr>
    <attr name="rncId">$rncId</attr>
    <attr name="rbsId">$args{MeContextId}</attr>
  </mo>
RBSLOCALCELL_TOPOLOGY
}

