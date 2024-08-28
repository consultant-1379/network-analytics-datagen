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
 This script creates and populates the TWAMP topology files with sample data.

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
# Handle RadioNodes nodes and TwampTestSessions
#
my @TwampTestSessions = get_moids( root_dir => $root_dir, mo_type => 'TwampTestSession' );
#my @node_config_files = get_configuration_info( root_dir => $root_dir, node_type => 'RadioNode' );
my @nodes_with_twamp  = @TwampTestSessions;

s{(MeContext=[^/]+)/.*}{$1} for @nodes_with_twamp; # strip off the node component
@nodes_with_twamp = do { my %seen; grep { !$seen{$_}++ } @nodes_with_twamp }; # find unique nodes

#print "TwampTestSessions = @TwampTestSessions\n";
#print "nodes_with_twamp = @nodes_with_twamp\n";

my %profileTypes = (
   1 => {
      Samples   => 3000,
      Frequency => 50,
   },
   2 => {
      Samples   => 600,
      Frequency => 10,
   },
);

my @profileTypes = (1, 2);

my @payloads     = (50, 100, 150, 200, 250, 300);
my @dscps        = (14, 18, 40, 46, 54);

my %twamp_test_session_config = (
   Baseband => {
      dstIpAddress => '192.168.0.1',
      dstNodeFDN   => 'SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=erbs_110001',
   },
   Baseband_T => {
      dstIpAddress => '10.10.10.5',
      dstNodeFDN   => 'SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210005',
   },
   DUS41_DUL20 => {
      dstIpAddress => '10.10.10.6',
      dstNodeFDN   => 'SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=erbs_210006',
   },
   EVO => {
      dstIpAddress => '10.0.0.100',
      dstNodeFDN   => 'SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=evo_100',
   },
   SIU_TCU02 => {
      dstIpAddress => '172.16.0.8',
      dstNodeFDN   => 'SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=tn_210008',
   },
   SSR_EPG => {
      dstIpAddress => '10.5.5.115',
      dstNodeFDN   => 'SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=epg_115',
   },
);

#print "twamp_test_session_config:\n", Dump(\%twamp_test_session_config);


for my $node (@nodes_with_twamp) {
   my ($node_id, $node_index) = $node =~ m/MeContext=(\S+(\d\d))/;
   #   print "node = $node\n";
   #print "node_id = $node_id\n";
   debug("node : $node");

   my $config        = LoadFile( "$node/$node_id.conf" );
   my $topology_dir  = "/eniq/data/pmdata/$config->{METADATA}{OSS_ID}/ipran/topologyData/twamp/twampSessionConfig";
   my $fdn           = "SubNetwork_$config->{METADATA}{ROOT_MO}_SubNetwork_$config->{METADATA}{SUBNETWORK}_MeContext_$node_id";
   my $topology_file = "$topology_dir/${fdn}_twampsessions.xml";

      mkpath( $topology_dir );   

      open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
      print {$TOPOLOGY_FH} "twampTestSessionId|userLabel|profileType|srcIpAddress|dstIpAddress|payload|dscp|srcNodeType|srcNodeFDN|dstNodeType|dstNodeFDN\n"; 

      #   print "topology_dir = $topology_dir\n";
      #print "twampTestSessionId|userLabel|profileType|srcIpAddress|dstIpAddress|payload|dscp|srcNodeType|srcNodeFDN|dstNodeType|dstNodeFDN\n";

   my @test_sessions = grep { /$node_id/ } @TwampTestSessions;

   my $test_index = 0;

   for my $test_session (@test_sessions) {
      # TwampTestSession format is <SourceNodeType>-<DestinationNodeType>-Service-DSCP-Profile-Payload
      #my ($test_index) = $test_session =~ m/-(\S+)$/;
      my ($twampTestSessionId) = $test_session =~ m/TwampTestSession=(\S+)$/;

      #
      my ($node_digits, $srcNodeType, $dstNodeType, $service, $dscp, $profile, $payload) = split /-/, $twampTestSessionId;
      
      #      print "test_session = $test_session\n";
      #print "test_session = ($twampTestSessionId, $node_digits, $srcNodeType, $dstNodeType, $service, $dscp, $profile, $payload)\n";

      my ($srcNodeFDN, $session_id, $session_index) = $test_session =~ m{(.*MeContext=[^/]+)\/.*=([^=]+-(\d+))};
      my $srcIpAddress = "10.0.0.$node_index";
      my $dstIpAddress = $twamp_test_session_config{$dstNodeType}{dstIpAddress};
      my $dstNodeFDN   = $twamp_test_session_config{$dstNodeType}{dstNodeFDN};

      $srcNodeFDN     =~ s{$root_dir/}{};
      $srcNodeFDN     =~ s{/}{,}g;

      my $userLabel = $node_id . '-' . $test_index++;

      #      my $profileType = $profileTypes[ $test_index % @profileTypes ];
      #my $payload     =     $payloads[ $test_index % @payloads ];
      #my $dscp        =        $dscps[ $test_index % @dscps ];

      print {$TOPOLOGY_FH} "$twampTestSessionId|$userLabel|$profile|$srcIpAddress|$dstIpAddress|$payload|$dscp|$srcNodeType|$srcNodeFDN|$dstNodeType|$dstNodeFDN\n";
   }     
   close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
}

exit 0;

