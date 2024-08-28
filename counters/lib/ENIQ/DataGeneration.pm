package ENIQ::DataGeneration;

use 5.008004;
use strict;
use warnings;
use Carp;
use lib '/eniq/home/dcuser/counters/lib';
use DateTime;
use File::Find; 
use File::Path; 
use List::Util qw(min max sum); 
use YAML::Tiny qw(Dump LoadFile DumpFile);

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use ENIQ::Reports ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
   'all' => [
      qw(

      )
   ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
clean_old_paths
debug
fetch_counter_formulas
file_footer
file_header
get_configuration_info
get_counter_files
get_counter_formulas
get_counter_formulas_with_pm_groups
get_current_time
get_default_arguments
get_managed_objects
get_managed_objects_with_pm_groups
get_moids
get_time_info
get_values_for
print_measurement_values
print_measurement_info_end
print_measurement_info_start
print_measurement_info_with_value
read_counters
reset_pmPowerConsumption
set_debug
set_power_configuration
set_twamp_values
set_voltage_configuration
twamp
);

our $VERSION = '1.0';
my $debug;
my %values_for;

my %node_prefix_for = (
   '5GRadioNode' => 'nr_',
   BSC       => 'bsc_',
   ERBS      => 'erbs_',
   HSS       => 'hss_',
   MGW       => 'mgw_',
   MRS       => 'mrs_',
   RadioNode => 'rn_',
   RBS       => 'rbs_',
   RNC       => 'rnc_',
   SBG       => 'sbg_',
   SGSN_MME  => 'sgsn_mme_',
);

# Preloaded methods go here.

#
# PM counter file handling routines
#

#
# This subroutine returns a string containing an XML snippet for a file header in either MDC or 3GPP format.
#
sub file_header {
   my ($config) = @_;
   return file_header_mdc($config)  if $config->{GENERATION} eq 'G1';
   return file_header_3gpp($config) if $config->{GENERATION} eq 'G2';
   lte_generation_warning( $config->{GENERATION} );
}

#
# This subroutine returns a string containing an XML snippet for a file header in either 3GPP format.
#
sub file_header_3gpp {
   my ($config) = @_;
   return <<"HEADER";
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type=text/xsl href="MeasDataCollection.xsl"?>
<measCollecFile xmlns="http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec">
<fileHeader fileFormatVersion="$config->{fileFormatVersion}" vendorName="$config->{vendorName}" dnPrefix="$config->{dnPrefix}">
<fileSender localDn="$config->{fsLocalDn}" elementType="$config->{elementType}"/>
<measCollec beginTime="$config->{beginTime}"/>
</fileHeader>
<measData>
<managedElement localDn="$config->{meLocalDn}" userLabel="$config->{userLabel}" swVersion="$config->{swVersion}"/>
HEADER
}

#
# This subroutine returns a string containing an XML snippet for a file header in either MDC format.
#
sub file_header_mdc {
   my ($config) = @_; 
   return <<"HEADER";
<?xml version="1.0"?>
<?xml-stylesheet type=text/xsl href="MeasDataCollection.xsl"?>
<!DOCTYPE mdc SYSTEM "MeasDataCollection.dtd">
<mdc xmlns:HTML="http://www.w3.org/TR/REC-xml">
   <mfh>
      <ffv>$config->{fileFormatVersion}</ffv>
      <sn>$config->{dnPrefix}</sn>
      <st></st>
      <vn>$config->{vendorName}</vn>
      <cbt>$config->{cbt}</cbt>
   </mfh>
   <md>
      <neid>
         <neun>$config->{userLabel}</neun>
         <nedn>$config->{dnPrefix}</nedn>
         <nesw>$config->{swVersion}</nesw>
      </neid>
HEADER
}

#
# This subroutine returns a string containing an XML snippet for a file footer in either MDC or 3GPP format.
#
sub file_footer {
   my ($config) = @_;
   return file_footer_mdc($config)  if $config->{GENERATION} eq 'G1';
   return file_footer_3gpp($config) if $config->{GENERATION} eq 'G2';
   lte_generation_warning( $config->{GENERATION} );
}

#
# This subroutine returns a string containing an XML snippet for a file footer in either 3GPP format.
#
sub file_footer_3gpp {
   my ($config) = @_;
   return <<"FOOTER";
</measData>
<fileFooter>
<measCollec endTime="$config->{endTime}"/>
</fileFooter>
</measCollecFile>
FOOTER
}

#
# This subroutine returns a string containing an XML snippet for a file footer in either MDC format.
#
sub file_footer_mdc {
   my ($config) = @_;
   return <<"FOOTER";
   </md>
   <mff><ts>$config->{ts}</ts></mff>
</mdc>
FOOTER
}

#
# This subroutine prints an XML snippet for a "measurement information start" in either MDC or 3GPP format.
#
sub print_measurement_info_start {
   my ($config) = @_;
   return print_measurement_info_start_mdc($config)  if $config->{GENERATION} eq 'G1';
   return print_measurement_info_start_3gpp($config) if $config->{GENERATION} eq 'G2';
   lte_generation_warning( $config->{GENERATION} );
}

#
# This subroutine prints an XML snippet for a "measurement information start" in either 3GPP format.
#
sub print_measurement_info_start_3gpp {
   my ($config) = @_;
   my @counters = sort keys %{ $config->{COUNTERS} };
   unless ($config->{ALLOW_UNDERSCORE_IN_COUNTER_NAMES}) {  # EnodeB Flex counters have underscore in the name
      s/_/./g for @counters;    # replace and underscores with dot, used in MME counters 
   }
   my $count    = 1;
   print { $config->{FILE_HANDLE} } "<measInfo measInfoId=\"$config->{measInfoId}\">\n";
   print { $config->{FILE_HANDLE} } "  <job jobId=\"$config->{jobId}\"/>\n";
   print { $config->{FILE_HANDLE} } "  <granPeriod duration=\"PT$config->{ROP_LENGTH}S\" endTime=\"$config->{endTime}\"/>\n";
   print { $config->{FILE_HANDLE} } "  <repPeriod duration=\"PT$config->{ROP_LENGTH}S\"/>\n";
   print { $config->{FILE_HANDLE} } "  <measType p=\"" . $count++ . "\">$_</measType>\n" for @counters;
   return;
}

#
# This subroutine prints an XML snippet for a "measurement information start" in either MDC format.
#
sub print_measurement_info_start_mdc {
   my ($config) = @_;
   my @counters = sort keys %{ $config->{COUNTERS} };
   s/_/./g for @counters;    # replace and underscores with dot, used in MME counters 
   print { $config->{FILE_HANDLE} } "      <mi>\n";
   print { $config->{FILE_HANDLE} } "         <mts>$config->{ts}</mts>\n";
   print { $config->{FILE_HANDLE} } "         <gp>$config->{ROP_LENGTH}</gp>\n";
   print { $config->{FILE_HANDLE} } "         <mt>$_</mt>\n" for @counters;
   return;
}

#
# This subroutine prints an XML snippet for a "measurement information end" in either MDC or 3GPP format.
#
sub print_measurement_info_end {
   my ($config) = @_;
   return print_measurement_info_end_mdc($config)  if $config->{GENERATION} eq 'G1';
   return print_measurement_info_end_3gpp($config) if $config->{GENERATION} eq 'G2';
   lte_generation_warning( $config->{GENERATION} );
}

#
# This subroutine prints an XML snippet for a "measurement information end" in either MDC or 3GPP format.
#
sub print_measurement_info_end_3gpp {
   my ($config) = @_;
   print { $config->{FILE_HANDLE} } "</measInfo>\n";
   return;
}

#
# This subroutine prints an XML snippet for a "measurement information end" in either MDC or 3GPP format.
#
sub print_measurement_info_end_mdc {
   my ($config) = @_;
   print { $config->{FILE_HANDLE} } "      </mi>\n";
   return;
}

#
# This subroutine prints an XML snippet for a "measurement values" in either MDC or 3GPP format.
#
sub print_measurement_values {
   my ($config) = @_;
   return print_measurement_values_mdc($config)  if $config->{GENERATION} eq 'G1';
   return print_measurement_values_3gpp($config) if $config->{GENERATION} eq 'G2';
   lte_generation_warning( $config->{GENERATION} );
}

#
# This subroutine prints an XML snippet for a "measurement values" in either 3GPP format.
#
sub print_measurement_values_3gpp {
   my ($config) = @_;
   print { $config->{FILE_HANDLE} } "  <measValue measObjLdn=\"$config->{measObjLdn}\">\n";
   print_counters( $config );
   print { $config->{FILE_HANDLE} } "  </measValue>\n";
   return;
}

#
# This subroutine prints an XML snippet for a "measurement values" in either MDC format.
#
sub print_measurement_values_mdc {
   my ($config) = @_;
   print { $config->{FILE_HANDLE} } "         <mv>\n";
   print { $config->{FILE_HANDLE} } "            <moid>$config->{measObjLdn}</moid>\n";
   print_counters( $config );
   print { $config->{FILE_HANDLE} } "         </mv>\n";
   return;
}

#
# This subroutine prints an XML snippet for a "counter values" in either MDC or 3GPP format.
#
sub print_counters {
   my ($config)                = @_;
   my $count                   = 1;
   my %counters_attributes_for = %{ $config->{COUNTERS} };

   eval $config->{FORMULAS};    # evaluate the formulas, the results are stored in values_for hash
   debug("FORMULAS : \n$config->{FORMULAS}");

   for my $counter ( sort keys %{ $config->{COUNTERS} } ) {
      $values_for{$counter} = get_accumulated_counter_value( 
         counter            => $counter, 
         counter_attributes => $counters_attributes_for{$counter}, 
         values_in          => $values_for{$counter}, 
         CONFIG             => $config 
      ) if $counters_attributes_for{$counter} =~ m/ACCUMULATED/;

      debug(sprintf "Values for %-30s = %6s", $counter, $values_for{$counter});
      if ($config->{GENERATION} eq 'G1') {
         print { $config->{FILE_HANDLE} }  "            <r>$values_for{$counter}</r>\n";
      } else {
         print { $config->{FILE_HANDLE} }  "  <r p=\"" . $count++ . "\">$values_for{$counter}</r>\n";
      }
   }
   return;
}

#
# This subroutine handles "Accumulated Counters" where a running total must be maintained across ROPs.
# The value is calculated, saved to a file and reloaded for the next ROP.
#
sub get_accumulated_counter_value {
   my %args         = @_;
   my $counter_dir  = "$args{CONFIG}->{ROOT_DIR}/$args{CONFIG}->{fdn}/$args{CONFIG}->{measObjLdn}";
   $counter_dir     =~ s{,}{/}g;
   my $counter_file = "$counter_dir/$args{counter}";
   debug("counter_file = $counter_file");

   my @values_in              = $args{values_in} =~ m/([.\w]+),?/g; # transform string values into array "1,2,3" => (1,2,3)
   my ($count_out, %bins_out) = split_compressed_pdf_into_bins(@values_in) if $args{counter_attributes} =~ m/COMPRESSED/;
   my @values_out             = (0) x @values_in; # initialise array of same size to zero    
   my $values_from_file       = LoadFile( $counter_file ) if -f $counter_file;

   debug("New values to be added     = @values_in");

   if ($args{counter_attributes} !~ m/COMPRESSED/) { # PDF counter is not compressed
      @values_out = @$values_from_file if defined $values_from_file;
      debug("Values before accumulation = @values_out");
      @values_out = map { $values_out[$_] + $values_in[$_] } (0 .. $#values_in);
   } 
   else {                                            # PDF counter is  compressed
      my ($count_in, %bins_in) = split_compressed_pdf_into_bins(@values_in);
      %bins_out                = map { $_ => 0 } sort keys %bins_in;    # initialise counters to zero
      ($count_out, %bins_out)  = split_compressed_pdf_into_bins(@$values_from_file) if defined $values_from_file;

      debug("Values in :", \%bins_in);
      debug("Values before accumulation :", \%bins_out);

      @values_out = map { $_ => $bins_out{$_} + $bins_in{$_} } sort keys %bins_out;
      unshift @values_out, $count_in;
   }
   debug("Values after  accumulation = @values_out");
   my $yaml_out = YAML::Tiny->new( \@values_out );
   $yaml_out->write( $counter_file  );

   return join ',', @values_out;
}

#
# This subroutine simply breaks a compressed PDF list into an integer (indicating number of bins) followed by a hash with the bin values.
#
sub split_compressed_pdf_into_bins {
   return shift, @_;
}




#

#
# Time routines
#

sub get_time_info {
   my ( $rop_length, $timezone, $utc )  = @_;

   my $now_epoch          = int( DateTime->now(time_zone => $timezone)->epoch / $rop_length) * $rop_length; # Round down to last ROP boundary;
   my $start_datetime     = DateTime->from_epoch( epoch => $now_epoch, time_zone => $timezone )->subtract(seconds => $rop_length);
   my $end_datetime       = DateTime->from_epoch( epoch => $now_epoch, time_zone => $timezone );

   my $now_epoch_utc      = int( DateTime->now()->epoch / $rop_length) * $rop_length; # Round down to last ROP boundary;
   my $start_datetime_utc = DateTime->from_epoch( epoch => $now_epoch_utc )->subtract(seconds => $rop_length);
   my $end_datetime_utc   = DateTime->from_epoch( epoch => $now_epoch_utc );

   my $file_start_time    = $start_datetime->strftime('%Y%m%d.%H%M%z');
   my $file_end_time      =   $end_datetime->strftime('%H%M%z');
   my $file_date_time     = "$file_start_time-$file_end_time";

   my $begin_time         = $start_datetime->strftime('%Y%m%d%H%M%S%z');
   my $end_time           =   $end_datetime->strftime('%Y%m%d%H%M%S%z');

   my $begin_time_utc     = $start_datetime_utc->strftime('%Y%m%d%H%M%SZ');
   my $end_time_utc       =   $end_datetime_utc->strftime('%Y%m%d%H%M%SZ');

   my $begin_time_3gpp    = $start_datetime->strftime('%Y-%m-%dT%H:%M:%S%z');
   my $end_time_3gpp      =   $end_datetime->strftime('%Y-%m-%dT%H:%M:%S%z');

   my $begin_time_3gpp_utc = $start_datetime_utc->strftime('%Y-%m-%dT%H:%M:%SZ');
   my $end_time_3gpp_utc   =   $end_datetime_utc->strftime('%Y-%m-%dT%H:%M:%SZ');

   if ($debug) {
      print "      start_datetime  = $start_datetime\n";
      print "      end_datetime    = $end_datetime\n";
      print "      rop_length      = $rop_length\n";
      print "      file_start_time = $file_start_time\n";
      print "      file_end_time   = $file_end_time\n";
      print "      file_date_time  = $file_date_time\n";
      print "      begin_time      = $begin_time\n";
      print "      end_time        = $end_time\n\n";
   }

   if ($utc) {
      return ($file_date_time, $begin_time_utc, $end_time_utc, $begin_time_3gpp_utc, $end_time_3gpp_utc );
   }
   else {
      return ($file_date_time, $begin_time, $end_time, $begin_time_3gpp, $end_time_3gpp );
   }
}

sub get_current_time {
   my %args = @_;
   my $date_format = $args{date_format} || '%Y-%m-%d %H:%M:%S'; # use this as default if date_format not supplied
   my $now = DateTime->now(time_zone => $args{timezone});
   return $now->strftime( $date_format );
}

#
# Configuration file handling
#

#
# This subroutine returns a list of all files in directories starting with root_dir, and with a .conf extension having node_prefix in the name.
#
# Example of a config file:
# /eniq/home/dcuser/ManagedObjects/SubNetwork=ONRM_RootMo/SubNetwork=LRAN/MeContext=rn_210022/rn_210022.conf
#
sub get_configuration_info {
   my %args = @_;
   my @config_files;
   my $node_prefix = $node_prefix_for{ $args{node_type} };
   find( sub { push @config_files, $File::Find::name if -f and /\b$node_prefix\w+\.conf$/ }, $args{root_dir} );
   return @config_files;
}

#
# This subroutine returns a hash of key=<MO Class> and values=<list of MOIDs> for that class
#
# Example of a fragment of this hash:
#
# EUtranCellFDD:
#  - SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210069,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=210069-2
#  - SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210069,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=210069-1
#  - SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210069,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=210069-3
# EUtranCellRelation:
#  - SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210069,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=210069-2,EUtranFreqRelation=775,EUtranCellRelation=210069-2-9
#  - SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210069,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=210069-2,EUtranFreqRelation=775,EUtranCellRelation=210069-2-10
#  - SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210069,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=210069-2,EUtranFreqRelation=775,EUtranCellRelation=210069-2-4
#
#
sub get_managed_objects {
   my %args = @_;

   # Find all directories representing Measured Object Instances
   my @instances;
   find( sub { push @instances, $File::Find::name if -d }, $args{root_dir} );
   map { s{$args{root_dir}/}{}; s{/}{,}g } @instances;  # strip off common path prefix
#   if ($debug) { print "instances: $_\n" for @instances; <F14>}

   # Find all counter classes
   my @counter_classes = get_counter_classes( node_counter_dir => $args{node_counter_dir} );
#   print "counter_classes: @counter_classes\n" if $debug;

#   my $mo_class_search = "(@counter_classes)[^=]*=[\\w\\*-]+\$";

   # Remove instances which don't have any counters defined in a counters file

   # Create a regex match to extract the MO class name from the FDN  
   my $mo_class_search = "(@counter_classes)(\\.\\w+)?=[\\w\\*-]+\$"; # Optional part is due to some SBG classes, e.g. NetworkQoS.netId=1

   # Create a list of FDNs that have classes matching the regex
   $mo_class_search =~ s/ /|/g; # need to use bar char for alternative match patterns

   # Example search below
   # mo_class_search = (NetworkQoS|ProxyRegistrar|ProxyRegistrarV6|SgcCp|SignalingNetworkConnection|Sip|SipV6)(\.\w+)?=[\w\*-]+$

   print "mo_class_search = $mo_class_search\n" if $debug;
   my @moids = grep { /$mo_class_search/ } @instances;

   # Package the instances up for easier traversal later
   my %moids_for;
   for my $moid (@moids) {
      my ($mo_type) = $moid =~ m/(\w+)(\.\w+)?=[\w*-]+$/;
#       print "get_managed_objects: mo_type = $mo_type\t moid = $moid\n" if $debug;
      push(@{$moids_for{$mo_type}}, $moid);
   }

   return %moids_for;
}

sub get_managed_objects_with_pm_groups {
   my %args = @_;

   # Find all directories representing Measured Object Instances
   my @instances;
   find( sub { push @instances, $File::Find::name if -d and $File::Find::name =~ m/$args{node_type}/ }, $args{root_dir} );
   map { s{$args{root_dir}/}{}; s{/}{,}g } @instances;  # strip off common path prefix
#   if ($debug) { print "instances: $_\n" for @instances; }

   # Find all counter classes
   my %counter_classes_with_pm_groups = get_counter_classes_with_pm_groups( node_counter_dir => $args{node_counter_dir} );
   print "Counter Classes :\n", Dump( \%counter_classes_with_pm_groups ) if $debug;

   my %moids_for;

   for my $pm_group (sort keys %counter_classes_with_pm_groups) {
      my @counter_classes;
      push @counter_classes, keys %{ $counter_classes_with_pm_groups{$pm_group} };
#      print "counter_classes:  pm_group = $pm_group, @counter_classes\n" if $debug;
      
      # Remove instances which don't have any counters defined in a counters file
      
      # Create a regex match to extract the MO class name from the FDN  
      my $mo_class_search = "(@counter_classes)(\\.\\w+)?=[\\w\\*\\._,-]+\$"; # Optional part is due to some SBG classes, e.g. NetworkQoS.netId=1

      # Create a list of FDNs that have classes matching the regex
      $mo_class_search =~ s/ /|/g; # need to use bar char for alternative match patterns

      # Example search below
      # mo_class_search = (NetworkQoS|ProxyRegistrar|ProxyRegistrarV6|SgcCp|SignalingNetworkConnection|Sip|SipV6)(\.\w+)?=[\w\*-]+$

      print "mo_class_search = $mo_class_search\n" if $debug;
      my @moids = grep { /$mo_class_search/ } @instances;

      # Package the instances up for easier traversal later
      for my $moid (@moids) {
         my ($mo_type) = $moid =~ m/(\w+)(\.\w+)?=[\w*\._,-]+$/;
#          print "get_managed_objects: pm_group = $pm_group, mo_type = $mo_type\t moid = $moid\n" if $debug;
         push(@{$moids_for{$pm_group}{$mo_type}}, $moid);
      }
   }
   return %moids_for;
}

#
# This subroutine returns a list of all MOIDs in directories starting with root_dir.
#
sub get_moids {
   my %args = @_;
   my @moids;
   find( sub { push @moids, $File::Find::name if -d and /\b$args{mo_type}=[^=]+$/ }, $args{root_dir} );
   return @moids;
}

#
# This subroutine returns a list of all MO Classes in directories starting with node_counter_dir with a .counters extension.
#
sub get_counter_classes {
   my %args = @_;
   my %counter_classes;
   find( sub { $counter_classes{$1} = $File::Find::name if -f and $File::Find::name =~ m/([\w\-]+)\.counters$/ }, $args{node_counter_dir} );
   return sort keys %counter_classes;
}

sub get_counter_classes_with_pm_groups {
   my %args = @_;
   my %counter_classes;
   find( sub { $counter_classes{$1}{$2} = $File::Find::name if -f and $File::Find::name =~ m/([\w\-]+)\/([\w\-]+)\.counters$/ }, $args{node_counter_dir} );

#   print "Counter Classes :\n", Dump( \%counter_classes ) if $debug;
   return %counter_classes;
}

#
# This subroutine returns a multi-dimensional hash of
#  - keys = <Node Version>
#              <NE MIM Version>
#                 <MO Class>
#                    <COUNTERS>
#                       <Counter Name>
#  - values = <Counter Type>
#
#  - keys = <Node Version>
#              <NE MIM Version>
#                 <MO Class>
#                    <FORMULAS>
#  - values = <String representing the formula for deriving a value for this counter>
#
# Example of a fragment of this hash:
#
#L15B:
#  F.1.100:
#    Cdma20001xRttCellRelation:
#      COUNTERS:
#        pmHoPrepAtt1xRttSrvcc: PEG
#        pmHoPrepSucc1xRttSrvcc: PEG
#      FORMULAS: "$values_for{pmHoPrepAtt1xRttSrvcc}  = int ( rand(10) + 20 );\n$values_for{pmHoPrepSucc1xRttSrvcc} = int ( $values_for{pmHoPrepAtt1xRttSrvcc}  - rand($values_for{pmHoPrepAtt1xRttSrvcc}  * 0.005) ) ;\n"
#    EUtranCellFDD:
#      COUNTERS:
#        pmCellDowntimeMan: PEG
#        pmCellHoExeAttLteInterF: PEG
#        pmCellHoExeAttLteIntraF: PEG
# 
#
# This show that counters are stored in a hash named "values_for" and shows the relationships between the counters involved in a KPI formula.
#
sub get_counter_formulas {
   my %args = @_;

   my %counter_formulas_for;
   my %counter_file_for = get_counter_files( node_counter_dir => $args{node_counter_dir});

   for my $node_version (keys %counter_file_for) {
      for my $ne_mim_version (keys %{ $counter_file_for{$node_version} } ) {
         for my $mo_type (keys %{ $counter_file_for{$node_version}{$ne_mim_version} } ) {
            my ($formulas, %counters) = fetch_counter_formulas( $counter_file_for{$node_version}{$ne_mim_version}{$mo_type} );
            $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{FORMULAS} = $formulas;
            $counter_formulas_for{$node_version}{$ne_mim_version}{$mo_type}{COUNTERS} = \%counters;
         }
      }
   }
#   print "Counter Formulas :\n", Dump( \%counter_formulas_for ) if $debug;
   return %counter_formulas_for;
}

sub get_counter_formulas_with_pm_groups {
   my %args = @_;

   my %counter_formulas_for;
   my %counter_file_for = get_counter_files_with_pm_groups( node_counter_dir => $args{node_counter_dir});

   for my $node_version (keys %counter_file_for) {
      for my $ne_mim_version (keys %{ $counter_file_for{$node_version} } ) {
         for my $pm_group (keys %{ $counter_file_for{$node_version}{$ne_mim_version} } ) {
            for my $mo_type (keys %{ $counter_file_for{$node_version}{$ne_mim_version}{$pm_group} } ) {
               my ($formulas, %counters) = fetch_counter_formulas( $counter_file_for{$node_version}{$ne_mim_version}{$pm_group}{$mo_type} );
               $counter_formulas_for{$node_version}{$ne_mim_version}{$pm_group}{$mo_type}{FORMULAS} = $formulas;
               $counter_formulas_for{$node_version}{$ne_mim_version}{$pm_group}{$mo_type}{COUNTERS} = \%counters;
            }
         }
      }
   }
   print "Counter Formulas :\n", Dump( \%counter_formulas_for ) if $debug;
   return %counter_formulas_for;
}

#
# This subroutine returns a multi-dimensional hash of 
#  - keys = <Node Version>
#              <NE MIM Version>
#                 <MO Class>
#  - values = <File Name>
#
# Example of a fragment of this hash:
#
#L15B:
#  F.1.100:
#    Cdma20001xRttCellRelation: /eniq/home/dcuser/counters/nodes/ERBS/Counters/L15B/F.1.100/Cdma20001xRttCellRelation.counters
#    EUtranCellFDD: /eniq/home/dcuser/counters/nodes/ERBS/Counters/L15B/F.1.100/EUtranCellFDD.counters
#    EUtranCellRelation: /eniq/home/dcuser/counters/nodes/ERBS/Counters/L15B/F.1.100/EUtranCellRelation.counters

sub get_counter_files {
   my %args = @_;
   my %counter_files;
   find( sub { $counter_files{$1}{$2}{$3} = $File::Find::name if -f and $File::Find::name =~ m!([\w\.-]+)/([\w\.-]+)/(\w+)\.counters$! }, $args{node_counter_dir} );

#   print "Counter Files List :\n", Dump( \%counter_files ) if $debug;
   return %counter_files;
}

sub get_counter_files_with_pm_groups {
   my %args = @_;
   my %counter_files;
   find( sub { $counter_files{$1}{$2}{$3}{$4} = $File::Find::name if -f and $File::Find::name =~ m!([\w\.-]+)/([\w\.-]+)/([\w\.-]+)/(\w+)\.counters$! }, $args{node_counter_dir} );

#   print "Counter Files List :\n", Dump( \%counter_files ) if $debug;
   return %counter_files;
}

#
# This subroutine returns a string containing counter formulas, and a hash of key=<Counter Name> and value=<Counter Type>
#
# Example of a formula string (note that it is multi-line):
#
# "$values_for{pmHoPrepAtt}        = int ( rand(20) );
# $values_for{pmHoPrepSucc}       = int ( $values_for{pmHoPrepAtt}  - rand($values_for{pmHoPrepAtt}  * 0.025) ) ;
# $values_for{pmHoExeAtt}         = int ( $values_for{pmHoPrepSucc} - rand($values_for{pmHoPrepSucc} * 0.005) ) ;
# $values_for{pmHoExeSucc}        = int ( $values_for{pmHoExeAtt} - rand($values_for{pmHoExeAtt} * 0.025) ) ;"
#
# Example of a fragment of this hash:
#
# pmHoExeAtt: PEG
# pmHoExeSucc: PEG
# pmHoPrepAtt: PEG
# pmHoPrepSucc: PEG
#
sub fetch_counter_formulas {
   my ($counter_file) = @_;
   my %counters;
   my $constants;
   my $formulas;

   open my $COUNTER_FH, '<', $counter_file or croak "Cannot open file $counter_file, $!";
   while (<$COUNTER_FH>) {
      chomp;
      next if m/^\s*#/ or m/^\s*$/;        # skip lines with only comments or blank

      # Extract counter attributes from comments on each counter line, each attribute is enclosed in [].
      # Format is pmCounter # [type 1] [type 2]
      # Valid types are PEG, GUAGE, ACCUMULATED, PDF, COMPRESSED
      # Example: pmAccumulatedEnergyConsumption = int ( rand(100) ) # [ACCUMULATED]
      my $counter_attributes = get_counter_attributes($_);

      s/#.*//;                              # throw away any comments
      if (m/^\s*_/) {                       # extract constants (must start with _ char)
         my ( $var, $value ) = split /\s*=\s*/;
         $constants .= "use constant $var => $value;\n";
      }
      else {                                # extract counter info
         my ( $counter, $formula ) = split /\s*\+?=\s*/;
         $counters{$counter}       = $counter_attributes;

         s/\b(       # start capture at boundary
         (?<![,%'[]) # must not be preceeded by % or , or [ or '
         [A-Za-z]    # must start with alpha char
         \w+\b       # any chars ending at a boundary
         (?![(']))   # must not be followed by a ( or '
         /\$values_for{$1}/gx; # change any word that starts with a char to hash variable


         s/\$values_for\{(int|rand|join|x|sprintf|sum|min|max)\}/$1/g; # restore any perl reserved words used (int, rand, sprintf, sum, min, max )
         s{\b(sum|min|max) }{$1 split /,/, }g;                  # reformulate to handle summation or other functions, if any
         $formulas .= "$_;\n";                                  # save formula
      }
   }
   close $COUNTER_FH or croak "Cannot close file $counter_file, $!";
   eval $constants if $constants; # bring values of constants into local namespace
   print "Fetch Counters and Formulas :\n   Formulas=$formulas\n   Counters=\n", Dump( \%counters ) if $debug;
   return ($formulas, %counters);
}

#
# This subroutine returns a string containing counter attributes.
# Valid attributes are PEG, GUAGE, ACCUMULATED, PDF, COMPRESSED
#
sub get_counter_attributes {
   my ($counter_string) = shift;
   my $counter_attributes;

   while ($counter_string =~ m/\[(\w+)\]/g) {
      $counter_attributes .= "$1,";
   }

   chop $counter_attributes if $counter_attributes;  # strip off trailing comma, if any
   $counter_attributes ||= 'PEG';                    # PEG is the default if no attributes found
   #   print "Counter attributes = $counter_attributes\n" if $debug and $counter_attributes;
   return $counter_attributes;   
}




#
# Functions
#

# This block mechanism is used to simulate a State variable power_state used for the Energy Feature
{
   my @bins            = (0) x 150;        # One value every 6s, so for one ROP gives 900/6 = 150
   my $max_power       = 40;               # Default maximum transmission power of a node in watts
   my $power_variation = 3;                # Default maximum deviation from baseline power level in any given ROP
   my $power_state     = rand($max_power); # Set initial power value
   my $min_power       = $max_power * 0.1; # Assume some minimum background level of power
   my @pmPowerConsumption;

   sub set_power_configuration {
      my %args         = @_;
      $max_power       = $args{max_power};
      $power_variation = $args{power_variation};
   }

   sub get_powerConsumption {
      $power_state += rand($power_variation);
      $power_state -= rand($power_variation);
      $power_state  = $max_power                    if $power_state > $max_power;
      $power_state  = $min_power + rand($min_power) if $power_state < $min_power;
      return $power_state;
   }

   sub powerConsumption {
      my @currentPowerConsumption = map{ get_powerConsumption() } @bins; # get the values for the current ROP
      @pmPowerConsumption = map {$pmPowerConsumption[$_] + $currentPowerConsumption[$_]} (0 .. $#pmPowerConsumption); # save accumulated values
      return @currentPowerConsumption;
   }
   
   sub reset_pmPowerConsumption {
      @pmPowerConsumption = map{0} @bins;
   }

   sub total_pmPowerConsumption {
      return @pmPowerConsumption;
   }
}

# This block mechanism is used to simulate a State variable voltage_state used for the Energy Feature
{
   my @bins              = (0) x 150;    # One value every 6s, so for one ROP gives 900/6 = 150
   my $max_voltage       = -48;          # Default maximum voltage in volts
   my $voltage_variation = 1;            # Default maximum deviation from baseline voltage level in any given ROP
   my $voltage_state     = $max_voltage; # Set initial voltage value

   sub set_voltage_configuration {
      my %args           = @_;
      $max_voltage       = $args{max_voltage};
      $voltage_variation = $args{voltage_variation};
   }

   sub get_voltage {
      $voltage_state  = $max_voltage;        # Set initial voltage value
      $voltage_state += rand($voltage_variation);
      $voltage_state -= rand($voltage_variation);
      return $voltage_state;
   }

   sub voltage {
      return map{ get_voltage() } @bins;
   }
}

# This block mechanism is used to simulate a State variable twamp used for the TWAMP Feature
{

   my %twamp;
   my $twamp_measure_parameters_file = '/eniq/home/dcuser/counters/etc/twamp_measure_parameters.yml';
   my $twamp_measure_parameters      = LoadFile( $twamp_measure_parameters_file ) if -f $twamp_measure_parameters_file;
   my %twamp_measure_parameters      = %{ $twamp_measure_parameters }; # convert to a hash

   my $moid;

   sub twamp {
      my ($measure, $stat) =@_;
      return join ',', @{$twamp{$measure}{$stat}};
   }

   sub set_twamp_values {
      my $moid = shift;
      %twamp   = get_twamp_values($moid);
   }

   sub get_twamp_values {
      my $moid = shift;
      debug("TWAMP MOID = $moid");
      my ($twampTestSessionId) = $moid =~ m/TwampTestSession=(\S+)$/;
      my ($node_digits, $srcNodeType, $dstNodeType, $service, $dscp, $profile, $payload) = split /-/, $twampTestSessionId;
      
      debug("test_session = ($twampTestSessionId, $node_digits, $srcNodeType, $dstNodeType, $service, $dscp, $profile, $payload)");

      my %twamp;

      my $ttl      = int(255 - rand(4));
      my $tx_pkts  = ($profile == 1) ? 3000 : 600; # 3000 samples for profile 1, 600 for profile 2
      my $duration = ($profile == 1) ? 20   : 100; # 20 ms period duration for profile 1, 100 for profile 2

      for my $minute (0..14) {

         my %lost_packets = (
            Fwd => int(rand(1.03)),
            Rev => int(rand(1.2)),
         );

         my %duplicated_packets = (
            Fwd => int(rand(1.6)),
            Rev => int(rand(1.05)),
         );

         my %reordered_packets = (
            Fwd => int(rand(1.1)),
            Rev => int(rand(2.3)),
         );

         $twamp{txPkts}{max}[$minute] = $tx_pkts;

         # add some random variation for received packets, can be greater due to duplicates or less due to lost
         $twamp{rxPkts}{max}[$minute] = $tx_pkts + $duplicated_packets{Fwd} + $duplicated_packets{Rev} - $lost_packets{Fwd} - $lost_packets{Rev};
                                      
         # Normally no packets are lost            
         for my $direction (qw(Fwd Rev)) {
            $twamp{     "lostPkts$direction"}{max}[$minute] = $lost_packets{$direction};
            $twamp{   "reorderPkt$direction"}{max}[$minute] = $reordered_packets{$direction};
            $twamp{    "duplicPkt$direction"}{max}[$minute] = $duplicated_packets{$direction};
            $twamp{  "lostPeriods$direction"}{max}[$minute] = $lost_packets{$direction};  # this doesn't have to be the same as lostPkts, but is here for simplicity
            
            $twamp{"lostPeriodMax$direction"}{max}[$minute] = $lost_packets{$direction} * $duration;
            $twamp{"lostPeriodMin$direction"}{min}[$minute] = $lost_packets{$direction} * $duration;

            $twamp{       "ttlMax$direction"}{max}[$minute] = $ttl;
            $twamp{       "ttlMin$direction"}{min}[$minute] = $ttl;
         }

         # Normal case is for same DSCP value to be returned
         for my $measure (qw(dscpRec)) {
            $twamp{$measure}{max}[$minute] = $dscp;
            $twamp{$measure}{min}[$minute] = $dscp;
         }

         for my $measure (qw(delayRt ipdvFwd ipdvRev)) {
            my @nums = get_random_nums(@{ $twamp_measure_parameters{$measure} });
            $twamp{$measure}{max}[$minute] = max(@nums);
            $twamp{$measure}{min}[$minute] = min(@nums);
            $twamp{$measure}{avg}[$minute] = int(sum(@nums)/@nums);
            $twamp{$measure}{p95}[$minute] = int(max(@nums) * 0.95);
            $twamp{$measure}{p98}[$minute] = int(max(@nums) * 0.98);
            $twamp{$measure}{p99}[$minute] = int(max(@nums) * 0.99);
         }
      }
      return %twamp;
   }

   sub get_random_nums {
      my $max_nums  = shift || 20;
      my $min_value = shift || 10;
      my $max_value = shift || 1000;
      return map { int( rand($max_value - $min_value)) + $min_value } (1..$max_nums);
   }
}



#
# Utility routines
#
sub clean_old_paths {
   my %args = @_;
   my @old_paths;
   find( sub { push @old_paths, $File::Find::name if -d and /\b$args{node_prefix}\w+/ }, $args{root_dir} );
   #   print "@old_paths\n";
   rmtree($_) for @old_paths;
}



#
# Debug routines
#
sub debug {
   my ($message, $values_ref) = @_;
   print "$message\n" if $debug;
   print Dump( $values_ref ) if $debug and $values_ref;
}

sub set_debug {
   $debug = 1;
}

#
# Local utility routines
#

sub lte_generation_warning {
   my ($generation) = @_;
   warn "Unknown LTE generation : $generation\nMust be either G1 or G2.\n";
}

#
# Deprecated subroutines
#
# These need some refactoring to make them compatible
#
#
#

sub get_config_files {
   my %args = @_;
   my @config_files;
   find( sub { push @config_files, $File::Find::name if -f and /\.conf$/ }, $args{root_dir} );
   return @config_files;
}


sub get_configuration_data {
   my %args = @_;
   my %config;
   open my $CONF_FH, '<', $args{node_config_file} or croak "Cannot open file $args{node_config_file}, $!";

   while (<$CONF_FH>) {
      chomp;                                                                # no newline
      s/#.*//xm;                                                            # no comments
      s/^\s+//xm;                                                           # no leading white
      s/\s+$//xm;                                                           # no trailing white
      next unless length;                                                   # anything left?
      my ( $var, $value ) = split /\s*=\s*/xm, $_, 2;
      $config{ $args{node_id} }{$var} = $value;
   }

   close $CONF_FH or croak "Cannot close file $args{node_config_file}, $!";
   return %config;
}

sub get_values_for {
   my ( $formulas ) = @_;
   eval "$formulas";    # evaluate the formulas, the results are stored in values_for hash
   return %values_for;
}


sub print_measurement_info_with_value {
   my ( $FH, $rop_length_in_seconds, $stopdate, $meas_info_id, $counter, $measObjLdn, $value ) = @_;
   my $count = 1;

   print {$FH} "<measInfo measInfoId=\"$meas_info_id\">\n";
   print {$FH} "  <job jobId=\"1\"/>\n";
   print {$FH} "  <granPeriod duration=\"PT${rop_length_in_seconds}S\" endTime=\"$stopdate\"/>\n";
   print {$FH} "  <repPeriod duration=\"PT${rop_length_in_seconds}S\"/>\n";
   print {$FH} "  <measType p=\"1\">$counter</measType>\n";
   print {$FH} "  <measValue measObjLdn=\"$measObjLdn\">\n";
   print {$FH} "  <r p=\"1\">$value</r>\n";
   print {$FH} "  </measValue>\n";
   print {$FH} "</measInfo>\n";
   return;
}




1;

__END__

$Author: eeikcoy $

$Date: 2007-09-12 10:43:34 +0100 (Wed, 12 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/lib/ENIQ/Reports.pm $

$Id: Reports.pm 55 2007-09-12 09:43:34Z eeikcoy $



# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

<Module::Name> - <One-line description of module's purpose>


=head1 VERSION

The initial template usually just has:

This documentation refers to <Module::Name> version 0.0.1.


=head1 SYNOPSIS

    use <Module::Name>;
    # Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.


=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.
(See also "Documenting Errors" in Chapter 13.)


=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.
(See also "Configuration Files" in Chapter 19.)


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.


=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

The initial template usually just has:

There are no known bugs in this module.
Please report problems to <Maintainer name(s)>  (<contact address>)
Patches are welcome.

=head1 AUTHOR

<Author name(s)> (<contact address>)



=head1 LICENSE AND COPYRIGHT

Copyright (c) <year> <copyright holder> (<contact address>). All rights reserved.

followed by whatever licence you wish to release it under.
For Perl code that is often just:

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

