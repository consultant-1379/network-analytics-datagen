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
my $session_group_description = 'VOICE';

# Need to modify this for MSA testing. 
# Set to a different value on each server. 
# Possible values are (1, 2, 3)
# Also need to uncomment the lines indicated below
my $msa_sdc_id = 1;  


for my $sdc_id (1 .. $number_of_sdc) {
# Uncomment the next line for MSA testing
#   next unless $sdc_id == $msa_sdc_id;
    my $oss_id = $oss_list[$sdc_id - 1];
   my $output_dir = "/eniq/data/pmdata/$oss_id/sdc_mm_10/dir1";
   mkpath($output_dir);

   my $sdc = sprintf "sdc_%02d", $sdc_id;
   debug("SDC : $sdc");
   debug("OSS_ID: $oss_id");

   my $sdc_file = "$output_dir/$sdc-$session_group_description-TWAMP-SESSION_GROUP-AAAA-${cbt}.xml";

   open my $FILE_HANDLE, '>', "$sdc_file" or croak "Cannot open file $sdc_file, $!";  
   print { $FILE_HANDLE } get_file_header();

   for my $node_index ( 1 .. $nodes_per_sdc) {
      my $session_id = sprintf "$sdc_id%03d", $sdc_id * $nodes_per_sdc + $node_index - 1;  
      debug("SESSION_ID:  $session_id");
      print { $FILE_HANDLE } get_rr_values($session_id);   
   }

   print { $FILE_HANDLE } get_file_footer(), "\n";
   close $FILE_HANDLE or croak "Cannot close file $sdc_file, $!";
}



exit 0;


sub get_random_nums {
   my $max_nums  = shift || 20;
   my $min_value = shift || 10;
   my $max_value = shift || 1000;
   return map { int( rand($max_value - $min_value)) + $min_value } (1..$max_nums);
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

sub get_rr_values {
   my ($session_id) = @_;
   my $stat_time = time() . '000'; # time in nano seconds

   my %rr;

   for my $direction ( 0 .. 1 ) {
      for my $measure ( qw(dp dvp jp) ) {
         my @nums          = get_random_nums();
         $rr{$measure}{$direction}{Hi} = max(@nums);
         $rr{$measure}{$direction}{Mi} = int(sum(@nums)/@nums);
         $rr{$measure}{$direction}{Lo} = min(@nums);
         $rr{$measure}{$direction}{25} = int(max(@nums) * 0.25);
         $rr{$measure}{$direction}{50} = int(max(@nums) * 0.50);
         $rr{$measure}{$direction}{75} = int(max(@nums) * 0.75);
         $rr{$measure}{$direction}{95} = int(max(@nums) * 0.95);
      }

      for my $measure ( qw(d dv j) ) {
         my @nums          = get_random_nums();
         $rr{$measure}{$direction}{max}  = max(@nums);
         $rr{$measure}{$direction}{mean} = int(sum(@nums)/@nums);
         $rr{$measure}{$direction}{min}  = min(@nums);
      }
         
      my @nums                 = get_random_nums();
      $rr{rxpkts}{$direction}  = sum(@nums);
      $rr{rxbytes}{$direction} = sum(@nums) * 10;

   }

   return <<"VALUES";
  <RR cid="1407483486000" sid="$session_id" eod="0">
    <RR1 direction="0" statStatus="18176" syncStatus="5963793" firstpktOffset="26116" lastpktOffset="1516" firstpktSeq="70236" lastpktSeq="70482" statTime="$stat_time" intervalms="900000" statRound="235" rxpkts="$rr{rxpkts}{0}" rxbytes="$rr{rxbytes}{0}" misorderpkts="0" duplicatepkts="0" toolatepkts="0" lostpkts="15" lostperiods="1" lostburstmin="15" lostburstmax="15" lostperc="50000" mos="3922838" ttlmin="251" ttlmax="251" tosmin="0" tosmax="0" vpriomin="4" vpriomax="4" cksum="0" dmin="$rr{d}{0}{min}" dp25="$rr{dp}{0}{25}" dp50="$rr{dp}{0}{50}" dp75="$rr{dp}{0}{75}" dp95="$rr{dp}{0}{95}" dpLo="$rr{dp}{0}{Lo}" dpMi="$rr{dp}{0}{Mi}" dpHi="$rr{dp}{0}{Hi}" dmax="$rr{d}{0}{max}" dmean="$rr{d}{0}{mean}" dStdDev="1" jmin="$rr{j}{0}{min}" jp25="$rr{jp}{0}{25}" jp50="$rr{jp}{0}{50}" jp75="$rr{jp}{0}{75}" jp95="$rr{jp}{0}{95}" jpLo="$rr{jp}{0}{Lo}" jpMi="$rr{jp}{0}{Mi}" jpHi="$rr{jp}{0}{Hi}" jmax="$rr{j}{0}{max}" jmean="$rr{j}{0}{mean}" jStdDev="1" dvp25="$rr{dvp}{0}{25}" dvp50="$rr{dvp}{0}{50}" dvp75="$rr{dvp}{0}{75}" dvp95="$rr{dvp}{0}{95}" dvpLo="$rr{dvp}{0}{Lo}" dvpMi="$rr{dvp}{0}{Mi}" dvpHi="$rr{dvp}{0}{Hi}" dvmax="$rr{dv}{0}{max}" dvmean="$rr{dv}{0}{mean}" />
    <RR1 direction="1" statStatus="1792" syncStatus="5963793" firstpktOffset="26116" lastpktOffset="1516" firstpktSeq="479023" lastpktSeq="479269" statTime="$stat_time" intervalms="900000" statRound="235" rxpkts="$rr{rxpkts}{1}" rxbytes="$rr{rxbytes}{1}" misorderpkts="0" duplicatepkts="0" toolatepkts="0" lostpkts="144" lostperiods="3" lostburstmin="38" lostburstmax="53" lostperc="505263" mos="1597886" ttlmin="250" ttlmax="250" tosmin="64" tosmax="64" vpriomin="4" vpriomax="4" cksum="0" dmin="$rr{d}{1}{min}" dp25="$rr{dp}{1}{25}" dp50="$rr{dp}{1}{50}" dp75="$rr{dp}{1}{75}" dp95="$rr{dp}{1}{95}" dpLo="$rr{dp}{1}{Lo}" dpMi="$rr{dp}{1}{Mi}" dpHi="$rr{dp}{1}{Hi}" dmax="$rr{d}{1}{max}" dmean="$rr{d}{1}{mean}" dStdDev="358" jmin="$rr{j}{1}{min}" jp25="$rr{jp}{1}{25}" jp50="$rr{jp}{1}{50}" jp75="$rr{jp}{1}{75}" jp95="$rr{jp}{1}{95}" jpLo="$rr{jp}{1}{Lo}" jpMi="$rr{jp}{1}{Mi}" jpHi="$rr{jp}{1}{Hi}" jmax="$rr{j}{1}{max}" jmean="$rr{j}{1}{mean}" jStdDev="498" dvp25="$rr{dvp}{1}{25}" dvp50="$rr{dvp}{1}{50}" dvp75="$rr{dvp}{1}{75}" dvp95="$rr{dvp}{1}{95}" dvpLo="$rr{dvp}{1}{Lo}" dvpMi="$rr{dvp}{1}{Mi}" dvpHi="$rr{dvp}{1}{Hi}" dvmax="$rr{dv}{1}{max}" dvmean="$rr{dv}{1}{mean}" />
  </RR>
VALUES
}
