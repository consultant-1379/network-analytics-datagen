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
 This script creates and populates the LTE RAN topology files with sample data.

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

my @all_eutran_cells;
push @all_eutran_cells, @{ $moids_for{EUtranCellFDD} } if $moids_for{EUtranCellFDD};
push @all_eutran_cells, @{ $moids_for{EUtranCellTDD} } if $moids_for{EUtranCellTDD};

print "node_config_files :\n", Dump( \@node_config_files ) if $debug;

my %node_functions = (
   GSM   => 'BTSFunction',
   LTE   => 'ENodeBFunction',
   WCDMA => 'NodeBFunction',
);

my %node_dispatch_table = (
   GSM   => \&bts_topology,
   LTE   => \&erbs_topology,
   WCDMA => \&rbs_topology,
);

my %moid_dispatch_table = (
   BbProcessingResource      => \&BbProcessingResource_topology,
   Cdma20001xRttBandRelation => \&Empty_topology,
   Cdma20001xRttCellRelation => \&Cdma20001xRttCellRelation_topology,
   Cdma20001xRttFreqRelation => \&Empty_topology,
   ConsumedEnergy            => \&Empty_topology,
   ConsumedEnergyMeasurement => \&Empty_topology,
   EFuse                     => \&Empty_topology,
   EnergyMeter               => \&Empty_topology,
   EnergyMeasurement         => \&EnergyMeasurement_topology,
   ENodeBFunction            => \&ENodeBFunction_topology,
   EUtranCellRelation        => \&EUtranCellRelation_topology,
   EUtranFreqRelation        => \&Empty_topology,
   EUtranCellFDD             => \&EUtranCell_topology,
   EUtranCellTDD             => \&EUtranCell_topology,
   FieldReplaceableUnit      => \&Empty_topology,
   GeranCellRelation         => \&GeranCellRelation_topology,
   GeranFreqGroupRelation    => \&Empty_topology,
   HsDschResources           => \&HsDschResources_topology,
   MpProcessingResource      => \&MpProcessingResource_topology,
   NodeBFunction             => \&NodeBFunction_topology,
   RbsLocalCell              => \&RbsLocalCell_topology,
   Router                    => \&Empty_topology,
   SectorCarrier             => \&SectorCarrier_topology,
   TwampInitiator            => \&Empty_topology,
   TwampTestSession          => \&Empty_topology,
   UtranCellRelation         => \&UtranCellRelation_topology,
   UtranFreqRelation         => \&Empty_topology,
);


for my $node_config_file (@node_config_files) {
#   my ($node) = $node_config_file =~ m{([^/]+).conf};
   my ($node, $node_index) = $node_config_file =~ m{([^/]+?(\d{4})).conf};
   debug("node : $node");

   my $config        = LoadFile( $node_config_file );
   my $fdn           = "SubNetwork=$config->{METADATA}{ROOT_MO},SubNetwork=$config->{METADATA}{SUBNETWORK},MeContext=$node";

   for my $rat_type (@{ $config->{METADATA}{RAT_TYPES} }) {
      debug("RAT : $rat_type");
      my $topology_dir  = "/eniq/data/pmdata/$config->{METADATA}{OSS_ID}/$config->{$rat_type}{TOPOLOGY_DIR}";
      my $topology_file = "$topology_dir/${fdn}.xml";
      my $current_time  = get_current_time( timezone => $config->{ATTRIBUTES}{timeZone} );

      mkpath( $topology_dir );   

      open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
      print {$TOPOLOGY_FH} topology_header();    
      print {$TOPOLOGY_FH} $node_dispatch_table{$rat_type}->( 
         CONFIG            => $config,
         node              => $node,
         fdn               => $fdn,
         fingerprint       => $node,
         MeContextId       => $node,
         siteRef           => "SubNetwork=$config->{METADATA}{ROOT_MO},Site=$config->{ATTRIBUTES}{siteRef}$node_index",
         timestampOfChange => $current_time,
         userLabel         => $node,
      );

      print "moids_for :\n", Dump( \%moids_for ) if $debug;

      for my $mo_type (keys %moids_for) {
         debug("mo_type:  $mo_type");

         my @node_mos = grep { /$fdn/ } @{ $moids_for{$mo_type} }; # find managed objects belonging to this node

         for my $moid (@node_mos) {
            next unless $moid =~ m/,$node_functions{$rat_type}=/;  # skip unless RAT type matches
            debug("moid:  $moid");
            print {$TOPOLOGY_FH} $moid_dispatch_table{$mo_type}->( 
               CELL_LIST         => \@all_eutran_cells, 
               CONFIG            => $config,
               fdn               => $moid,
               MeContextId       => $node,
               MO_TYPE           => $mo_type,
               timestampOfChange => $current_time,
            );
         }
      }
      
      print {$TOPOLOGY_FH} topology_footer(), "\n";
      close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
   }
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

sub Empty_topology {
# TODO Placeholder
 return;
}

sub erbs_topology {
   my %args      = @_;

   return <<"ERBS_TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ERBS_NODE_MODEL">
    <attr name="MeContextId">$args{MeContextId}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="neMIMversion">$args{CONFIG}->{ATTRIBUTES}{neMIMversion}</attr>
    <attr name="swVersion">$args{CONFIG}->{ATTRIBUTES}{swVersion}</attr>
    <attr name="siteRef">$args{siteRef}</attr>
    <attr name="fingerprint">$args{fingerprint}</attr>
    <attr name="nodeVersion">$args{CONFIG}->{ATTRIBUTES}{nodeVersion}</attr>
    <attr name="managedElementType">$args{CONFIG}->{ATTRIBUTES}{managedElementType}</attr>
  </mo>
  <mo fdn="$args{fdn},ManagedElement=1,ENodeBFunction=1" mimName="ERBS_NODE_MODEL">
    <attr name="eNBId">$args{node}</attr>
    <attr name="eNodeBPlmnId">
      <struct>
        <attr name="mcc">$args{CONFIG}->{ATTRIBUTES}{mcc}</attr>
        <attr name="mnc">$args{CONFIG}->{ATTRIBUTES}{mnc}</attr>
        <attr name="mncLength">$args{CONFIG}->{ATTRIBUTES}{mncLength}</attr>
      </struct>
    </attr>
    <attr name="timeZone">$args{CONFIG}->{ATTRIBUTES}{timeZone}</attr>
    <attr name="neMIMversion">$args{CONFIG}->{ATTRIBUTES}{neMIMversion}</attr>
    <attr name="worldTimeZoneId">$args{CONFIG}->{ATTRIBUTES}{worldTimeZoneId}</attr>
    <attr name="daylightSavingsAdjust">$args{CONFIG}->{ATTRIBUTES}{daylightSavingsAdjust}</attr>
    <attr name="statusAnr">2</attr>
    <attr name="statusPci">1</attr>
    <attr name="timestampOfChange">$args{timestampOfChange}</attr>
  </mo>
ERBS_TOPOLOGY
}

sub rbs_topology {
   my %args    = @_;
   my ($rncId) = $args{CONFIG}->{WCDMA}{associatedRnc} =~ m/=([^=]+)$/;
   return <<"NODE_TOPOLOGY";
  <mo fdn="$args{fdn}">
    <attr name="MeContextId">$args{MeContextId}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="neMIMversion">$args{CONFIG}->{ATTRIBUTES}{neMIMversion}</attr>
    <attr name="swVersion">$args{CONFIG}->{ATTRIBUTES}{swVersion}</attr>
    <attr name="siteRef">SubNetwork=$args{CONFIG}->{METADATA}{ROOT_MO},Site=$args{CONFIG}->{ATTRIBUTES}{siteRef}</attr>
    <attr name="nodeVersion">$args{CONFIG}->{ATTRIBUTES}{nodeVersion}</attr>
    <attr name="managedElementType">$args{CONFIG}->{ATTRIBUTES}{managedElementType}</attr>
    <attr name="MNC">$args{CONFIG}->{ATTRIBUTES}{mnc}</attr>
    <attr name="MCC">$args{CONFIG}->{ATTRIBUTES}{mcc}</attr>
    <attr name="associatedRnc">$args{CONFIG}->{WCDMA}{associatedRnc}</attr>
    <attr name="rncId">$rncId</attr>
  </mo>
NODE_TOPOLOGY
}


sub bts_topology {
   my %args    = @_;
   my ($bscId) = $args{CONFIG}->{GSM}{associatedBsc} =~ m/=([^=]+)$/;
   return <<"NODE_TOPOLOGY";
  <mo fdn="$args{fdn}">
    <attr name="MeContextId">$args{MeContextId}</attr>
    <attr name="userLabel">$args{userLabel}</attr>
    <attr name="siteRef">SubNetwork=$args{CONFIG}->{METADATA}{ROOT_MO},Site=$args{CONFIG}->{ATTRIBUTES}{siteRef}</attr>
    <attr name="nodeVersion">$args{CONFIG}->{ATTRIBUTES}{nodeVersion}</attr>
    <attr name="managedElementType">$args{CONFIG}->{ATTRIBUTES}{managedElementType}</attr>
  </mo>
NODE_TOPOLOGY
}



sub EnergyMeasurement_topology {
# TODO
 return;
}

sub RbsLocalCell_topology {
# TODO
 return;
}

sub HsDschResources_topology {
# TODO
 return;
}

sub NodeBFunction_topology {
# TODO
 return;
}


sub BbProcessingResource_topology {
# TODO
 return;
}

sub ENodeBFunction_topology {
# TODO
 return;
}

sub MpProcessingResource_topology {
# TODO
 return;
}

sub EUtranCell_topology {
   my %args      = @_;
   my ($node_id) = $args{fdn} =~ m/MeContext=\w+?(\d+)/;

   my ($cell_id, $cell_index) = $args{fdn} =~ m/($node_id-([^-]+))/;
   
   return <<"CELL_TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ERBS_NODE_MODEL">
    <attr name="$args{MO_TYPE}Id">$cell_id</attr>
    <attr name="cellId">$cell_index</attr>
    <attr name="earfcndl">3750</attr>
    <attr name="earfcnul">21750</attr>
    <attr name="sectorCarrierRef">
      <seq count="1">
        <item>$args{fdn},ManagedElement=1,ENodeBFunction=1,SectorCarrier=$cell_id</item>
      </seq>
    </attr>
    <attr name="tac">11001</attr>
    <attr name="lastModification">1</attr>
    <attr name="physicalLayerSubCellId">0</attr>
    <attr name="physicalLayerCellIdGroup">121</attr>
    <attr name="activePlmnList">
      <seq count="1">
        <item>
          <struct>
            <attr name="mcc">$args{CONFIG}->{ATTRIBUTES}{mcc}</attr>
            <attr name="mnc">$args{CONFIG}->{ATTRIBUTES}{mnc}</attr>
            <attr name="mncLength">$args{CONFIG}->{ATTRIBUTES}{mncLength}</attr>
          </struct>
        </item>
      </seq>
    </attr>
    <attr name="additionalPlmnList">
      <seq count="1">
        <item>
          <struct>
            <attr name="mcc">1</attr>
            <attr name="mnc">1</attr>
            <attr name="mncLength">2</attr>
          </struct>
        </item>
      </seq>
    </attr>
    <attr name="userLabel">$cell_id</attr>
    <attr name="timestampOfChange">$args{timestampOfChange}</attr>
    <attr name="hostingDigitalUnit">$args{fdn},ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1</attr>
    <attr name="noOfPucchCqiUsers">730</attr>
    <attr name="noOfPucchSrUsers">730</attr>
    <attr name="cellRange">15</attr>
    <attr name="ulChannelBandwidth">5000</attr>
    <attr name="pdcchCfiMode">5</attr>
  </mo>
CELL_TOPOLOGY
}

sub EUtranCellRelation_topology {
   my %args = @_;
      
   my @cells = @{ $args{CELL_LIST} };
   my ($current_cell, $current_cell_type) = $args{fdn} =~ m/(.*EUtranCell(\w+)[^,]+),/;
   my $adjacent_cell = '';
   my $adjacent_cell_type;

   do {
      $adjacent_cell = $cells[ int(rand(@cells)) ];  
      ($adjacent_cell_type) = $adjacent_cell =~ m/EUtranCell(\w+)/;
   } until ( 
      ($adjacent_cell ne $current_cell)              # select one of the cells at random until it differs from current cell
      and 
      ($adjacent_cell_type eq $current_cell_type) ); # ensure HO is between cells of the same type FDD or TDD

   return <<"TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ERBS_NODE_MODEL">
    <attr name="createdBy">1</attr>
    <attr name="adjacentCell">$adjacent_cell</attr>
    <attr name="neighborCellRef">$adjacent_cell</attr>
    <attr name="anrCreated"/>
    <attr name="isHoAllowed">true</attr>
    <attr name="isRemoveAllowed">false</attr>
    <attr name="sCellCandidate">1</attr>
    <attr name="lastModification">1</attr>
    <attr name="timestampOfChange">$args{timestampOfChange}</attr>
  </mo>
TOPOLOGY
}

sub Cdma20001xRttCellRelation_topology {
# Note that there is no equivalent table for Cdma20001xRttCellRelation in the LTE tech Pack, so just ignore these
 return;
}

sub GeranCellRelation_topology {
   my %args          = @_;
   my $me_context    = sprintf "%04d", int(rand(10000)) + 1; # Create a random Node ID
   my $cell_index    = int(rand(3)) + 1;
   my $adjacent_cell = "$me_context-$cell_index";

   return <<"TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ERBS_NODE_MODEL">
    <attr name="adjacentCell">SubNetwork=$args{CONFIG}->{METADATA}{ROOT_MO},ExternalGeranCell=$adjacent_cell</attr>
    <attr name="createdBy">4</attr>
    <attr name="externalGeranCellFDDRef">SubNetwork=$args{CONFIG}->{METADATA}{ROOT_MO},MeContext=$me_context,ManagedElement=1,ENodeBFunction=1,GeraNetwork=1,ExternalGeranCell=$adjacent_cell</attr>
    <attr name="isHoAllowed">true</attr>
    <attr name="timeOfCreation">$args{timestampOfChange}</attr>
    <attr name="GeranCellRelationId">$adjacent_cell</attr>
    <attr name="timestampOfChange">$args{timestampOfChange}</attr>
  </mo>
TOPOLOGY
}

sub SectorCarrier_topology {
   my %args                   = @_;
   my ($me_context, $node_id) = $args{fdn} =~ m/(.*MeContext=\w+?(\d+))/;
   my ($carrier_id, $index)   = $args{fdn} =~ m/($node_id-([^-]+))/;

   my $cell_type = ($index <= 3) ? 'EUtranCellFDD' : 'EUtranCellTDD'; # FDD cells are 1 to 3, TDD from 4 to 6

   return <<"TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ERBS_NODE_MODEL">
    <attr name="SectorCarrierId">$carrier_id</attr>
    <attr name="reservedBy">
      <seq count="1">
        <item>$me_context,ManagedElement=1,ENodeBFunction=1,$cell_type=$carrier_id</item>
      </seq>
    </attr>
    <attr name="timestampOfChange">$args{timestampOfChange}</attr>
    <attr name="noOfRxAntennas">2</attr>
  </mo>
TOPOLOGY
}

sub UtranCellRelation_topology {
   my %args          = @_;
   my $me_context    = sprintf "%04d", int(rand(10000)) + 1; # Create a random Node ID
   my $cell_index    = int(rand(3)) + 1;
   my $adjacent_cell = "$me_context-$cell_index";

   return <<"TOPOLOGY";
  <mo fdn="$args{fdn}" mimName="ERBS_NODE_MODEL">
    <attr name="adjacentCell">SubNetwork=$args{CONFIG}->{METADATA}{ROOT_MO},ExternalUtranCell=$adjacent_cell</attr>
    <attr name="createdBy">4</attr>
    <attr name="externalUtranCellFDDRef">SubNetwork=$args{CONFIG}->{METADATA}{ROOT_MO},MeContext=$me_context,ManagedElement=1,ENodeBFunction=1,UtraNetwork=1,UtranFrequency=4400,ExternalUtranCellFDD=$adjacent_cell</attr>
    <attr name="isHoAllowed">true</attr>
    <attr name="timeOfCreation">$args{timestampOfChange}</attr>
    <attr name="UtranCellRelationId">$adjacent_cell</attr>
    <attr name="timestampOfChange">$args{timestampOfChange}</attr>
  </mo>
TOPOLOGY
}


