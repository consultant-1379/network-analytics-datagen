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
                number of NEs (SGSN-MMEs)   [default is 5]
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
   print "Start date           = $year_start-$month_start-$day_start\n";
   print "End date             = $year_end-$month_end-$day_end\n";
   print "Number of SGSN-MMEs  = $nes\n";
   print 'ROP time             = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of SGSN-MMEs ($nes) must be > 0\n\n$usage\n\n"                                            if $nes le '0';

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my @SGSN_MME_range  = get_ne_list( 'sgsn_mme_',  $nes );

my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/sgsn_mme_cba/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/sgsnmme';

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

# Some constants for SGSN-MME
my $elementType       = 'SGSN-MME';
my $swVersion         = '15B';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V9.0';

#my $measObjLdn = 'Blade=1-1,SipV6=1';

for my $day_index ( $day_start .. $day_end ) {
   my $day   = add_leading_zero($day_index);
   my $month = add_leading_zero($month_start);

   print "$year_start-$month-$day\n" if $verbose;

   my $date = "$year_start$month$day";

   for my $start_time ( sort keys %end_time_for ) {
      print "   time = $start_time\n" if $verbose;

      my $end_time = $end_time_for{$start_time};

      for my $SGSN_MME_id (@SGSN_MME_range) {
         print "      SGSN_MME_id = $SGSN_MME_id\n" if $verbose;

         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$timezone";

         my $dnPrefix  = "SubNetwork=ONRM_RootMo,MeContext=$SGSN_MME_id";
         my $localDn   = "$SGSN_MME_id";
         my $userLabel = "$SGSN_MME_id";

         my $SGSN_MME_file = "$data_dir/A$date.$start_time$timezone-$date.$end_time${timezone}_${dnPrefix}_statsfile.xml";
         open my $SGSN_MME_FH, '>', "$SGSN_MME_file" or croak "Cannot open file $SGSN_MME_file, $!";
         print {$SGSN_MME_FH} format_header_extended( $startdate, 'ManagedElement=1', $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $localDn), "\n";

         for my $mo_type ( sort keys %formulas_for ) {
            my $measObjLdn;
            if ($mo_type eq 'SGSN-MME_Session_SM_E_QCI') {
               for my $qos ( 1 .. 10 ) {
                  $measObjLdn = "ManagedElement=$SGSN_MME_id,SgsnMme=1,QosClassIdentifier=$qos";
                  print "      mo_type = $mo_type\n" if $verbose;
                  print "      measObjLdn = $measObjLdn\n" if $verbose;

                  my @counters_list = sort split /:/mx, $counters_for{$mo_type};
                  my @counter_names = @counters_list;
                  s/_/./g for @counter_names;
                  print_measurement_info_start_with_measInfoId( $SGSN_MME_FH, $rop_length_in_seconds, $stopdate, $mo_type, @counter_names );
                  print_measurement_values( $SGSN_MME_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
                  print_measurement_info_end($SGSN_MME_FH);
               }
            } elsif ($mo_type eq 'SGSN-MME_Mobility_MM_E') {
               $measObjLdn = "ManagedElement=$SGSN_MME_id,SgsnFunction=1";
               print "      mo_type = $mo_type\n" if $verbose;
               print "      measObjLdn = $measObjLdn\n" if $verbose;

               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               my @counter_names = @counters_list;
               s/_/./g for @counter_names;
               print_measurement_info_start_with_measInfoId( $SGSN_MME_FH, $rop_length_in_seconds, $stopdate, $mo_type, @counter_names );
               print_measurement_values( $SGSN_MME_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
               print_measurement_info_end($SGSN_MME_FH);
            } else {
               warn "Unknown counter type: $mo_type\n";
            }

         }

         print {$SGSN_MME_FH} format_footer($stopdate), "\n";
         close $SGSN_MME_FH or croak "Cannot close file $SGSN_MME_file, $!";
      }
   }
}

__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_sgsn-mme_counter_files.pl $

$Id: generate_SGSN-MME_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_SGSN-MME_counter_files - creates the ENIQ counter directories and files for SGSN-MME nodes.

=head1 VERSION

This documentation refers to generate_SGSN-MME_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_SGSN-MME_counter_files.pl [options] 

=back

 Example:
        generate_SGSN-MME_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_SGSN-MME_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_SGSN-MME_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20

 will create the ROP files for all counters, for the date range and SGSN-MMEs given.

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

=item * /eniq/data/pmdata/eniq_oss_1/SGSN-MME

=item * /eniq/data/pmdata/eniq_oss_1/SGSN-MME/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/SGSN-MME/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=SGSN-MME07,MeContext=SGSN-MME07_statsfile.xml

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


