#!/usr/bin/perl
use strict;
use warnings;

my $node_file = $ARGV[0];
my $data_file = $ARGV[1];

open my $node_fh, "<", $node_file or die "Could not open $node_file $!";
my @nodes = <$node_fh>;
close $node_fh or die "Could not close $node_file $!";

undef $/;
open my $data_fh, "<", $data_file or die "Could not open $data_file $!";
my $data = <$data_fh>;
close $data_fh or die "Could not close $data_file $!";

chop @nodes;

my $node_prefix = 'enb';
my $node_subnet = 'SubNetwork=ONRM_ROOT_MO,SubNetwork=LRAN,MeContext=';
my $node_index  = 1;

for my $node_fdn (@nodes) {

   my ($node_name)   = $node_fdn =~ m/.*=(\w+)/;
   my $new_node_name = sprintf "${node_prefix}_%04d", $node_index++;
   my $new_node_fdn  = "$node_subnet$new_node_name";
   my ($cell_prefix) = $node_name =~ m/(\w{5})/; # extract the first 5 chars as the cell prefix to replace

#   print "$node_fdn\t$new_node_fdn\n";

   $data =~ s/$node_fdn/$new_node_fdn/g;        # replace the node FDN
   $data =~ s/$node_name/$new_node_name/g;      # replace the node name
   $data =~ s/$cell_prefix/${new_node_name}_/g; # replace the cell name

   # Muli-System Access, change some nodes to use other OSSs
   $data =~ s/eniq_oss_1(.*enb_002)/eniq_oss_2$1/g if $new_node_name =~ m/enb_002/; # replace the OSS_ID
   $data =~ s/eniq_oss_1(.*enb_003)/eniq_oss_3$1/g if $new_node_name =~ m/enb_003/; # replace the OSS_ID
}

my $output_file = $data_file;
$output_file =~ s/(.*)(.csv)/${1}_anon$2/;

#print "$output_file\n";

open my $fh, ">", $output_file or die "Could not open $output_file $!";
print $fh $data;
close $fh or die "Could not close $output_file $!";

