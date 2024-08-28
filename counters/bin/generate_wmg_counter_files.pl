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
                number of NEs (WMGs)   [default is 5]
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -t <rop_time>, --time=<rop_time>
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
   print "Number of WMGs = $nes\n";
   print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of RNCs ($nes) must be > 0\n\n$usage\n\n"                                            if $nes le '0';

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my @WMG_range  = get_ne_list( 'wmg_',  $nes );

my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/wmg/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/wmg';

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

# Some constants for WMG
my $userLabel         = 'WMG';
my $elementType       = 'WMG';
my $swVersion         = 'R16B';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V8.0';

for my $day_index ( $day_start .. $day_end ) {
   my $day   = add_leading_zero($day_index);
   my $month = add_leading_zero($month_start);

   print "$year_start-$month-$day\n" if $verbose;

   my $date = "$year_start$month$day";

   for my $start_time ( sort keys %end_time_for ) {
      print "   time = $start_time\n" if $verbose;

      my $end_time = $end_time_for{$start_time};

      for my $wmg_id (@WMG_range) {
         print "      wmg_id = $wmg_id\n" if $verbose;

         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$timezone";

         my $localDn = "ManagedElement=$wmg_id";
         my $dnPrefix = "";

         my $WMG_file = "$data_dir/A$date.$start_time$timezone-$end_time${timezone}_${wmg_id}-1_epdg";
         open my $WMG_FH, '>', "$WMG_file" or croak "Cannot open file $WMG_file, $!";
         print {$WMG_FH} format_header_extended( $startdate, $localDn, $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $localDn), "\n";

         for my $mo_type ( sort keys %formulas_for ) {
            print "      mo_type = $mo_type\n" if $verbose;

            my $measObjLdn = "$mo_type,Group=1";
            $measObjLdn =~ s/-/,/g; # replace dash with comma

            print "      measObjLdn = $measObjLdn\n" if $verbose;

            my @counters_list = sort split /:/mx, $counters_for{$mo_type};
            my @counters_list_with_spaces = @counters_list;
            s/_/ /g for @counters_list_with_spaces;           # replace underscore with space in counter names
            s/Rate$/Rate %/g for @counters_list_with_spaces;  # all trailing % for counter names ending in Rate

            print_measurement_info_start( $WMG_FH, $rop_length_in_seconds, $stopdate, @counters_list_with_spaces );
            if ($measObjLdn !~ m/QCI/) {
               print_measurement_values( $WMG_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
            } else {
               for my $qci (1..9, 'OTHER') {
                  my $measObjLdn_qci = "$measObjLdn,QCI=QCI_$qci"; # Add QCI
                  print_measurement_values( $WMG_FH, $measObjLdn_qci, \@counters_list, $formulas_for{$mo_type} );
               }
            }
            print_measurement_info_end($WMG_FH);

         }

         print {$WMG_FH} format_footer($stopdate), "\n";
         close $WMG_FH or croak "Cannot close file $WMG_file, $!";

      }
   }
}

__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_WMG_counter_files.pl $

$Id: generate_WMG_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_WMG_counter_files - creates the ENIQ counter directories and files for WMG nodes.

=head1 VERSION

This documentation refers to generate_WMG_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_WMG_counter_files.pl [options] 

=back

 Example:
        generate_WMG_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_WMG_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_WMG_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20

 will create the ROP files for all counters, for the date range and WMGs given.

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

=item * /eniq/data/pmdata/eniq_oss_1/WMG

=item * /eniq/data/pmdata/eniq_oss_1/WMG/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/WMG/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=WMG07,MeContext=WMG07_statsfile.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/WMG

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/WMG/CSCF.counters

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

