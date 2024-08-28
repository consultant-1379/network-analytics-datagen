#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use Carp;
use Getopt::Long;
use YAML::Tiny qw(Dump LoadFile);
use ENIQ::DataGeneration;
use File::Path;
use List::Util qw (min max sum); 

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

my ($file_date_time, $cbt) = get_time_info(15, '+0100');
$cbt =~ s/Z/+0100/;

my $number_of_sdc = 3;
my $nodes_per_sdc = 10;
my @oss_list = qw(eniq_oss_1 eniq_oss_2 eniq_oss_3);

# Need to modify this for MSA testing. 
# Set to a different value on each server. 
# Possible values are (1, 2, 3)
# Also need to uncomment the lines indicated below
my $msa_sdc_id = 1;  

# Probe Config

for my $sdc_id (1 .. $number_of_sdc) {
# Uncomment the next line for MSA testing
#   next unless $sdc_id == $msa_sdc_id;
   my $oss_id = $oss_list[$sdc_id - 1];
   my $output_dir = "/eniq/data/pmdata/$oss_id/sdc_probe_config";
   mkpath($output_dir);

   my $sdc = sprintf "sdc_%02d", $sdc_id;
   debug("sdc : $sdc");

   my $probeconfig_file = "$output_dir/$sdc-probeconfig-${cbt}.xml";

   open my $FILE_HANDLE, '>', "$probeconfig_file" or croak "Cannot open file $probeconfig_file, $!";  
   print { $FILE_HANDLE } get_file_header();

   for my $node_index ( 1 .. $nodes_per_sdc) {
      my $dst_node = get_dst_node($sdc_id, $nodes_per_sdc, $node_index);
      debug("$dst_node:  $dst_node");
      print { $FILE_HANDLE } get_probeconfig_node($dst_node);   
   }

   print { $FILE_HANDLE } get_probeconfig_node('RNC_001');   
   print { $FILE_HANDLE } get_file_footer(), "\n";
   close $FILE_HANDLE or croak "Cannot close file $probeconfig_file, $!";
}

# Session Config

my $src_node   = 'RNC_001';

for my $sdc_id (1 .. $number_of_sdc) {
# Uncomment the next line for MSA testing
#   next unless $sdc_id == $msa_sdc_id;
   my $oss_id = $oss_list[$sdc_id - 1];
   my $output_dir = "/eniq/data/pmdata/$oss_id/sdc_session_config_16";
   mkpath($output_dir);

   my $sdc = sprintf "sdc_%02d", $sdc_id;
   debug("sdc : $sdc");

   for my $node_index ( 1 .. $nodes_per_sdc) {

      my $session_id = sprintf "$sdc_id%03d", $sdc_id * $nodes_per_sdc + $node_index - 1;
   
      my $sessionconfig_file = "$output_dir/$sdc-sessconfig-${session_id}-${cbt}.xml";

      open my $FILE_HANDLE, '>', "$sessionconfig_file" or croak "Cannot open file $sessionconfig_file, $!";  
      print { $FILE_HANDLE } get_file_header();

      my $dst_node = get_dst_node($sdc_id, $nodes_per_sdc, $node_index);
      my $session_name = "$src_node-$dst_node-voice";
      debug("         $dst_node:  $dst_node");
      print { $FILE_HANDLE } get_sessionconfig($session_id, $session_name, $src_node, $dst_node);   
      
      print { $FILE_HANDLE } get_file_footer(), "\n";
      close $FILE_HANDLE or croak "Cannot close file $sessionconfig_file, $!";
   }
}


# Responder Config

for my $sdc_id (1 .. $number_of_sdc) {
# Uncomment the next line for MSA testing
#   next unless $sdc_id == $msa_sdc_id;
   my $oss_id = $oss_list[$sdc_id - 1];
   my $output_dir = "/eniq/data/pmdata/$oss_id/dim_e_ipprobe/topology/ipfdn";
   my $responderconfig_file = "$output_dir/responderconfig.txt";
   mkpath($output_dir);

   open my $FILE_HANDLE, '>', "$responderconfig_file" or croak "Cannot open file $responderconfig_file, $!";  
   print { $FILE_HANDLE } get_responderconfig_header();

   my $sdc = sprintf "sdc_%02d", $sdc_id;
   debug("sdc : $sdc");

   for my $node_index ( 1 .. $nodes_per_sdc) {
      my $dst_node = get_dst_node($sdc_id, $nodes_per_sdc, $node_index);
      debug("         $dst_node:  $dst_node");
      print { $FILE_HANDLE } get_responderconfig($dst_node);   
   }

   close $FILE_HANDLE or croak "Cannot close file $responderconfig_file, $!";
}


exit 0;

sub get_dst_node {
   my ($sdc_id, $nodes_per_sdc, $node_index) = @_;
   return sprintf "enb_%04d", $sdc_id * $nodes_per_sdc + $node_index - 1;
}

sub get_file_header {
   return <<"HEADER";
<Ptexport ack="1" seq="1" version="1.5.0">
  <Response>
HEADER
}

sub get_file_footer {
   return <<"FOOTER";
  </Response>
</Ptexport>
FOOTER
}

sub get_probeconfig_node {
   my ($node_id) = @_;
   my ($node_index) = $node_id =~ m/\w+(..)/;
   $node_index = int($node_index);
   return <<"PROBECONFIG";
    <Node category="0" cid="1355670120000" name="$node_id" serialno="0" timezone="UTC+01:00" type="103" uid="0x0">
      <Interfaces>
        <Iface name="e1.100">
          <Addr ipv4="192.168.100.$node_index" mask="32"/>
        </Iface>
      </Interfaces>
    </Node>
PROBECONFIG
}

sub get_sessionconfig {
   my ($session_id, $session_name, $src_node, $dst_node) = @_;
   my ($node_index) = $dst_node =~ m/\w+(..)/;
   return <<"SESSIONCONFIG";
    <Sess cid="1355670120000" sid="$session_id" name="$session_name" type="10">
      <TwoWay>
        <OneWayConf rxPeerId="4655" txPeerId="4655" maxduration="643506" statInterval="900" ifname="e1.100" ipdst="192.168.100.$node_index" ipsrc="192.168.100.1" dport="4000" sport="14201" srcnodename="$src_node" dstnodename="$dst_node" flowType="udp" txVid="100" txVprio="1" iptos="72" plsize="82" plrate="6560" ipsync="0.0.0.0" createTime="1403695713" />
        <OneWayConf rxPeerId="4655" txPeerId="4655" maxduration="643506" statInterval="900" ifname="e1.100" ipdst="192.168.100.1" ipsrc="192.168.100.$node_index" dport="14201" sport="4000" srcnodename="$dst_node" dstnodename="$src_node" flowType="udp" txVid="100" txVprio="1" iptos="72" plsize="82" plrate="6560" ipsync="0.0.0.0" createTime="1403695713" />
      </TwoWay>
    </Sess>
SESSIONCONFIG
}

sub get_responderconfig_header {
   return <<"RESPONDERCONFIGHEADER";
responderFdn|ipAddress|udpPort|actualModes|administrativeState|availabilityStatus|operationalState|TwampResponderId|ipAccessHostEtRef|userLabel|vid|trafficSchedulerRef
RESPONDERCONFIGHEADER
}

sub get_responderconfig {
   my ($dst_node) = @_;
   return <<"RESPONDERCONFIG";
SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=$dst_node,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=$dst_node,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=$dst_node,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
RESPONDERCONFIG
}


__END__

SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS01,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS01,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS01,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS01,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=2|0.0.0.4|1|am4|0|0|0|tr4|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS01,ManagedElement=1,IpSystem=1,IpAccessHostEt=2|TR04|11|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS01,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=2
SubNetwork=ONRM_ROOT_MO_R,MeContext=ERBS01,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.1|1|am1|0|||1|SubNetwork=ONRM_ROOT_MO_R,MeContext=ERBS01,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR01|101|SubNetwork=ONRM_ROOT_MO_R,MeContext=ERBS01,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,MeContext=ERBS01,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=2|0.0.0.2|1|am2|0|||2|SubNetwork=ONRM_ROOT_MO_R,MeContext=ERBS01,ManagedElement=1,IpSystem=1,IpAccessHostEt=2|TR02|100|SubNetwork=ONRM_ROOT_MO_R,MeContext=ERBS01,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=2
SubNetwork=ONRM_ROOT_MO_R,MeContext=RNC001,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,MeContext=RNC001,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,MeContext=RNC001,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,MeContext=RNC002,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,MeContext=RNC002,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,MeContext=RNC002,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS800,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS800,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS800,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS801,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS801,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS801,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS802,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS802,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,SubNetwork=RNC01,MeContext=RBS802,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU800,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU800,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU800,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU300,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU300,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU300,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1
SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU200,ManagedElement=1,IpSystem=1,Ippm=1,TwampResponder=1|0.0.0.3|1|am3|0|0|0|tr3|SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU200,ManagedElement=1,IpSystem=1,IpAccessHostEt=1|TR03|10|SubNetwork=ONRM_ROOT_MO_R,MeContext=SIU200,ManagedElement=1,IpSystem=1,TrafficManagement=1,TrafficScheduler=1

