#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::ReportsXSD;
use Carp;

#use YAML::Tiny;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]
    -n <NEs>, --nes=<NEs>
                number of NEs (SBGs)   [default is 5]
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -r <rop_length>, --rop=<rop_length>
                ROP time
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 

 Example:
        $0 

 will create the ROP files for all counters in the input files.

 Example:
        $0 -s 2007-04-01 -e 2007-04-20 -r 20

 will create the ROP files for all counters in the input files, for the date range and number of nes given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.

USAGE

my ( $day_today, $month_today, $year_today ) = get_todays_date();

my $debug      = '';
my $help       = '';
my $verbose    = '';                                       # default is off
my $nes        = '5';                                      # default is 5
my $time       = '';
my $rop_length = 15;                                       # default is 15 minutes
my $start_date = "$year_today-$month_today-$day_today";    # default is today
my $end_date   = $start_date;                              # default is today

GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
   'nes=s'        => \$nes,
   'start_date=s' => \$start_date,
   'end_date=s'   => \$end_date,
   'time=s'       => \$time,
   'rop_length=s' => \$rop_length,
);

if ($help) {
    print "$usage\n\n\n";
    exit;
}

my ( $year_start, $month_start, $day_start ) = get_date_ymd($start_date);
my ( $year_end,   $month_end,   $day_end )   = get_date_ymd($end_date);

if ($verbose) {
   print "Start date      = $year_start-$month_start-$day_start\n";
   print "End date        = $year_end-$month_end-$day_end\n";
   print "Number of SBGs  = $nes\n";
   print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of SBGs ($nes) must be > 0\n\n$usage\n\n"                                            if $nes le '0';

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my @sbg_range  = get_ne_list( '',  $nes );

my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/SBG/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/sbg';

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
#print "Constants=[$constants]\n";
eval "$constants" if $constants;                # bring values of constants into local namespace

if ($debug) {
   print "Constants : \n$constants\n" if $constants;
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

create_pmdata_dirs($data_dir);

my %end_time_for = get_rop_times($time);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

# Some constants for SBG
my $userLabel         = 'SBG';
my $elementType       = 'SBG';
my $swVersion         = 'R3B';
my $vendorName        = 'Ericsson AB';
my $fileFormatVersion = '2.435 V7.2.0';

#my $measObjLdn = 'Blade=1-1,SipV6=1';

#my $moid_prefix = 'Blade=BLADE-1';
my $moid_prefix = 'SGC.bsNo=<BLADE>';

my %measurement_objects = (
   NetworkQoS                  => [ 
                                   'SGC.bsNo=9,NetworkQoS.netId=1', 
                                   'SGC.bsNo=9,NetworkQoS.netId=2', 
                                   'SGC.bsNo=9,NetworkQoS.netId=7', 
                                   'SGC.bsNo=10,NetworkQoS.netId=1', 
                                   'SGC.bsNo=10,NetworkQoS.netId=2', 
                                   'SGC.bsNo=10,NetworkQoS.netId=7', 
                                   'SGC.bsNo=11,NetworkQoS.netId=1', 
                                   'SGC.bsNo=11,NetworkQoS.netId=4', 
                                   'SGC.bsNo=11,NetworkQoS.netId=5', 
                                   'SGC.bsNo=12,NetworkQoS.netId=1', 
                                   'SGC.bsNo=12,NetworkQoS.netId=4', 
                                   'SGC.bsNo=12,NetworkQoS.netId=5', 
                                 ],
   ProxyRegistrar              => [ 
                                   'SGC.bsNo=9,SignalingNetworkConnection.netId=1,Sip.networkRole=1,ProxyRegistrar=*', 
                                   'sgc.bsno=10,signalingnetworkconnection.netid=1,sip.networkrole=1,ProxyRegistrar=*', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=1,Sip.networkRole=2,ProxyRegistrar=*', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=4,Sip.networkRole=2,ProxyRegistrar=*', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=5,Sip.networkRole=2,ProxyRegistrar=*', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=1,Sip.networkRole=2,ProxyRegistrar=*', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=4,Sip.networkRole=2,ProxyRegistrar=*', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=5,Sip.networkRole=2,ProxyRegistrar=*', 

                                 ],
   SignalingNetworkConnection => [ 
                                   'SGC.bsNo=9,SignalingNetworkConnection.netId=1', 
                                   'SGC.bsNo=10,SignalingNetworkConnection.netId=1', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=1', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=4', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=5', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=1', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=4', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=5', 
                                 ],
   Sip                        => [ 
                                   'SGC.bsNo=9,SignalingNetworkConnection.netId=1,Sip.networkRole=1', 
                                   'sgc.bsno=10,signalingnetworkconnection.netid=1,sip.networkrole=1', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=1,Sip.networkRole=2', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=4,Sip.networkRole=2', 
                                   'SGC.bsNo=11,SignalingNetworkConnection.netId=5,Sip.networkRole=2', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=1,Sip.networkRole=2', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=4,Sip.networkRole=2', 
                                   'SGC.bsNo=12,SignalingNetworkConnection.netId=5,Sip.networkRole=2', 
                                 ],
   
);

for my $day_index ( $day_start .. $day_end ) {
   my $day   = add_leading_zero($day_index);
   my $month = add_leading_zero($month_start);

   print "$year_start-$month-$day\n" if $verbose;

   my $date = "$year_start$month$day";

   for my $start_time ( sort keys %end_time_for ) {
      print "   time = $start_time\n" if $verbose;

      my $end_time = $end_time_for{$start_time};

      my $batch_id = 0;
      
      for my $sbg_id (@sbg_range) {
         print "      sbg_id = $sbg_id\n" if $verbose;

         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$timezone";

         $batch_id += 1;
            
         my $ne_name = sprintf("%02d", $sbg_id);
         my $dnPrefix = "SubNetwork=IsNetwork,IsSite=sbg_$ne_name";
         my $localDn = "bs=$sbg_id";

         my $sbg_file = "$data_dir/A$date.$start_time$timezone-$end_time${timezone}_-${batch_id}_ISSBG_${ne_name}_SBG_${sbg_id}";
         open my $SBG_FH, '>', "$sbg_file" or croak "Cannot open file $sbg_file, $!";
         print {$SBG_FH} format_header( $startdate, $localDn, $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion), "\n";


         for my $mo_type ( sort keys %formulas_for ) {
#            my $measObjLdn = 'Blade=BLADE-1,MO=1';
#            my $measObjLdn = 'SGC.bsNo=1,SignalingNetworkConnection.netId=1,Sip.networkRole=1';

            my @counters_list = sort split /:/mx, $counters_for{$mo_type};

            for my $moid (@{ $measurement_objects{$mo_type} }) {
               my $measObjLdn;
               if ($mo_type eq 'SignalingNetworkConnection') {
                  $measObjLdn = $moid; # use moid directly for SignalingNetworkConnection
               }
               else {
                  $measObjLdn = "$moid_prefix,$moid";
                  my $blade_id = int($sbg_id);
                  $measObjLdn =~ s/<BLADE>/$blade_id/;
               }
               
               print "      moid       = $moid      \n" if $verbose;
               print "      mo_type    = $mo_type   \n" if $verbose;
               print "      measObjLdn = $measObjLdn\n" if $verbose;

               print_measurement_info_start( $SBG_FH, $rop_length_in_seconds, $stopdate, @counters_list );
               print_measurement_values( $SBG_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
               print_measurement_info_end($SBG_FH);
            }
         }

         print {$SBG_FH} format_footer($stopdate), "\n";
         close $SBG_FH or croak "Cannot close file $sbg_file, $!";
      }
   }
}

__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_SBG_counter_files.pl $

$Id: generate_SBG_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_SBG_counter_files - creates the ENIQ counter directories and files for SBG nodes.

=head1 VERSION

This documentation refers to generate_SBG_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_SBG_counter_files.pl [options] 

=back

 Example:
        generate_SBG_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_SBG_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_SBG_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20

 will create the ROP files for all counters, for the date range and SBGs given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

    -n <NEs>, --nes=<NEs>
                number of NEs (RNCs)   [default is 20]
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 


=head1 DESCRIPTION

This script generates counter directories and files for the RNC nodes.

This script creates and populates the counter ROP files with sample data.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/SBG

=item * /eniq/data/pmdata/eniq_oss_1/SBG/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/SBG/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=SBG07,MeContext=SBG07_statsfile.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/SBG

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/SBG/CSCF.counters

=back

=head1 EXIT STATUS

None

=head1 CONFIGURATION

None

=head1 DEPENDENCIES

None

=head1 INCOMPATIBILITIES

None

=head1 BUGS AND LIMITATIONS

None

=head1 AUTHOR

eeikcoy

=head1 LICENSE AND COPYRIGHT

Ericsson (2008)

