#!/usr/bin/perl
use strict;
use warnings;
use Tie::File;

my $node_file = $ARGV[0];
my $data_file = $ARGV[1];

tie my @nodes, 'Tie::File', $node_file or die "Can't open $node_file";
tie my @data,  'Tie::File', $data_file or die "Can't open $data_file";

my $node_prefix = 'enb';
my $node_fdn    = 'SubNetwork=ONRM_ROOT_MO,SubNetwork=LRAN,MeContext=';
my $node_index  = 1;

for my $node (@nodes) {

   my ($node_name)   = $node =~ m/.*=(\w+)/;
   my $new_node_name = sprintf "${node_prefix}_%04d", $node_index++;
   my $new_node_fdn  = "$node_fdn$new_node_name";
   my ($cell_prefix) = $node_name =~ m/(\w{5})/; # extract the first 5 chars as the cell prefix to replace

#   print "$node\t$new_node_fdn\n";

   for (@data) {
      s/$node/$new_node_fdn/g;            # replace the node FDN
      s/$node_name/$new_node_name/g;      # replace the node name
      s/$cell_prefix/${new_node_name}_/g; # replace the cell name
   }
}

untie @nodes;
untie @data;

