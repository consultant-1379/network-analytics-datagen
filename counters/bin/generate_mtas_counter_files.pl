#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Carp;

#use YAML::Tiny;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]
    -n <NEs>, --nes=<NEs>
                number of NEs (MTAS)   [default is 5]
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
my $nes        = '10';                                     # default is 10
my $time       = '';
my $rop_length = 5;                                        # default is 5 minutes
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
   print "Start date           = $year_start-$month_start-$day_start\n";
   print "End date             = $year_end-$month_end-$day_end\n";
   print "Number of MTASs  = $nes\n";
   print 'ROP time             = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of MTASs ($nes) must be > 0\n\n$usage\n\n"                                           if $nes le '0';

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();


my %node_version_for  = (
   mtas_10 => '16B',
   mtas_11 => '16B',
   mtas_12 => '16B',
#   mtas_13 => '16B',
   mtas_14 => '17A',
#   mtas_15 => '17A',
#   mtas_16 => '17A',
#   mtas_17 => '17B',
#   mtas_18 => '17B',
   mtas_19 => '17B',
);


my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/MTAS/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/nodes/mtas';
my @mo_classes   = qw(MtasTraf MtasSubsData PlatformMeasures);
my @processors   = get_processors();

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
#print "Constants=[$constants]\n";
eval "$constants" if $constants;                # bring values of constants into local namespace

if ($debug) {
#   print "Constants : \n$constants\n";
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

my @mtas_range = sort keys %node_version_for;

create_pmdata_dirs($data_dir);

my %end_time_for = get_rop_times_5($time);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

# Some constants for MTAS
my $elementType       = 'MTAS';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V10.0';
my $measObjLdn        = 'DEFAULT';
my $node_name_prefix  = 'DC=ims.ericsson.se,g3SubNetwork=IMS,g3ManagedElement=';

for my $mo_class (@mo_classes) {

   my $constants = read_counters( "$counters_dir/$mo_class", \%counters_for, \%formulas_for );
#print "Constants=[$constants]\n";
   eval "$constants" if $constants;                # bring values of constants into local namespace

   if ($debug) {
      print "Constants : \n$constants\n" if $constants;
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
   }

   for my $day_index ( $day_start .. $day_end ) {
      my $day   = add_leading_zero($day_index);
      my $month = add_leading_zero($month_start);

      print "$year_start-$month-$day\n" if $verbose;

      my $date = "$year_start$month$day";    # don't insert / or -, this format is used in ROP file

      for my $start_time ( sort keys %end_time_for ) {
         print "   time = $start_time\n" if $verbose;

         my $end_time = $end_time_for{$start_time};

         for my $mtas_id (@mtas_range) {
            print "      mtas_id  = $mtas_id, version = $node_version_for{$mtas_id}\n" if $verbose;

            my $dnPrefix  = "$node_name_prefix$mtas_id";
            my $localDn   = "g3ManagedElement=$mtas_id";
            my $userLabel = $mtas_id;


            my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
            my $startdate = "$year_start$month${day}$hours${minutes}00$timezone";
            ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
            my $stopdate  = "$year_start$month${day}$hours${minutes}00$timezone";

            my $mtas_file = "$data_dir/A$date.$start_time-${end_time}_${mtas_id}_$mo_class";

            open my $MTAS_FH, '>', "$mtas_file" or croak "Cannot open file $mtas_file, $!";
            print {$MTAS_FH} ENIQ::Reports::format_header( $dnPrefix, $startdate, $fileFormatVersion, $vendorName, $node_version_for{$mtas_id});

            for my $functional_area ( sort keys %formulas_for ) {
               print "      functional_area = $functional_area\n" if $verbose;
               my $measObjLdn = $functional_area;

               my @counters_list = sort split /:/mx, $counters_for{$functional_area};
               print "      @counters_list\n" if $debug;

               if ($mo_class eq 'PlatformMeasures') {
                  for my $counter (@counters_list) {
                     if ($counter =~ m/DicosCpuLoad|MemUsage/) {
                        print_measurement_info_start( $MTAS_FH, $rop_length_in_seconds, $stopdate, ($counter) );
                        for my $processor (@processors) {
                           my %formula_values = get_values_for($formulas_for{$functional_area});
                           print_measurement_info( $MTAS_FH, "$functional_area=DEFAULT, Source=$processor", $formula_values{$counter});
                        }
                        print_measurement_info_end( $MTAS_FH );
                     }
                  }
               } else {
                  my %formula_values = ENIQ::Reports::get_values_for($formulas_for{$functional_area});
                  for my $counter (@counters_list) {
                     my $counter_value = $formula_values{$counter};
                     print "      $counter = $counter_value\n" if $debug;
                     my %values = ( "DEFAULT" => $counter_value );
                     ENIQ::Reports::print_measurement_info_with_values( $MTAS_FH, $rop_length_in_seconds, $stopdate, $counter, %values );
                  }
               }
            }

            print {$MTAS_FH} ENIQ::Reports::format_footer($stopdate), "\n";
            close $MTAS_FH or croak "Cannot close file $mtas_file, $!";
         }
      }
   }
}

#
#
# Subroutines
#
#

sub get_processors {
   return qw(
Proc_m0_s1
Proc_m0_s11
Proc_m0_s13
Proc_m0_s15
Proc_m0_s17
Proc_m0_s19
Proc_m0_s21
Proc_m0_s23
Proc_m0_s3
Proc_m0_s5
Proc_m0_s7
Proc_m0_s9
Proc_m1_s1
Proc_m1_s11
Proc_m1_s13
Proc_m1_s15
Proc_m1_s17
Proc_m1_s19
Proc_m1_s21
Proc_m1_s23
Proc_m1_s3
Proc_m1_s5
Proc_m1_s7
Proc_m1_s9
Proc_m2_s1
Proc_m2_s3
Proc_m2_s5
_SYSTEM
);
}


exit 0;






__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_MTAS_counter_files.pl $

$Id: generate_MTAS_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_MTAS_counter_files - creates the ENIQ counter directories and files for MTAS nodes.

=head1 VERSION

This documentation refers to generate_MTAS_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_MTAS_counter_files.pl [options] 

=back

 Example:
        generate_MTAS_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_MTAS_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_MTAS_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20

 will create the ROP files for all counters, for the date range and MTASs given.

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

=item * /eniq/data/pmdata/eniq_oss_1/MTAS

=item * /eniq/data/pmdata/eniq_oss_1/MTAS/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/MTAS/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=MTAS07,MeContext=MTAS07_statsfile.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/sgsnm

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/sgsnm

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



