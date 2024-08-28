#!/usr/bin/perl 
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Carp;

#use YAML::Tiny;

our ($VERSION) = '1.0';

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options] 

    -n <NEs>, --nes=<NEs>
                number of NEs (SGSNs)   [default is 5]
    -s <start_date>, --start_date=<start_date>
                start date             [default is today]
    -e <end_date>, --end_date=<end_date>
                end date               [default is today]
    -t <rop_time>, --time=<rop_time>
                ROP time               [default is all ROP times today]
    -r <rop_length>, --rop=<rop_length>
                ROP time
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 

 Example:
        $0 

 will create the ROP files for all counters for today.

 Example:
        generate_sgsn_counter_xml_files.pl -s 2007-04-01 -e 2007-04-20 -n 20 

 will create the ROP files for all counters, for the date range and SGSNs given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.
 
USAGE

my ( $day_today, $month_today, $year_today ) = get_todays_date();

my $nes        = '5';
my $debug      = '';                                       # Empty string
my $help       = '';                                       # Empty string
my $verbose    = '';                                       # Empty string
my $time       = '';                                       # Empty string
my $rop_length = 15;                                     # default is 15 minutes
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
    print "Start date     = $year_start-$month_start-$day_start\n";
    print "End date       = $year_end-$month_end-$day_end\n";
    print "Number of SGSNs = $nes\n";
    print 'ROP time       = ', ($time) ? $time : 'not specified', "\n";
    print "ROP length      = $rop_length\n";
}

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my $year  = $year_start;
my $month = $month_start;

my @sgsns = get_ne_list( 'sgsn', $nes );

my %max_instances_for = (
    Sgsn          => 1,    # 1 - 1
    SgsnMmNon     => 1,    # 1 - 1
    RoutingArea   => 5,    # 1 - 5 ? made this up, not sure of real value
    RoutingAreaSM => 5,  # 1 - 5 ? made this up, not sure of real value
);

my %moid_for = (
    Sgsn          => '',
    SgsnMmNon     => '',
    RoutingArea   => '353_871234500',
    RoutingAreaSM => '353_871234500',
);

# assume that all counters in an MO class are of the given type
my %counter_type_for = (
    Sgsn          => 'PEG',
    SgsnMmNon     => 'PEG',
    RoutingArea   => 'PEG',
    RoutingAreaSM => 'PEG',
);

my %counters_for;
my %formulas_for;
my %mo_accumulated;    # used to hold accumulated running values for MOs with multiple instances

my $data_dir     = "/eniq/data/pmdata/$oss_id/sgsn/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/sgsn';
my %end_time_for = get_rop_times($time);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
eval $constants;     # bring values of constants into local namespace

if ($debug) {
   print "Constants : \n$constants\n" if $constants;
   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

create_pmdata_dirs($data_dir);

my $measurement_job = 'pm1';
my %ne_version_for;
$ne_version_for{$_} = '14B' for 'sgsn01' .. 'sgsn20';   # ensure these are consistent with those created using generate_core_topology_files.pl
#$ne_version_for{$_} = 'R6.0' for 'sgsn21' .. 'sgsn40';
#$ne_version_for{$_} = 'R7.0' for 'sgsn21' .. 'sgsn40';

for my $day_index ( $day_start .. $day_end ) {
    my $day   = add_leading_zero($day_index);
    my $month = add_leading_zero($month);

    print "$year-$month-$day\n" if $verbose;

    my $date = "$year$month$day";    # don't insert / or -, this format is used in ROP file

    for my $start_time ( sort keys %end_time_for ) {
        print "   time = $start_time\n" if $verbose;

        my $end_time = $end_time_for{$start_time};

        for my $sgsn_id (@sgsns) {
            print "      sgsn_id = $sgsn_id\n" if $verbose;

            my $startdate = "$date${start_time}00$timezone";
            my $stopdate  = "$date${end_time}00$timezone";

            my $sgsn_fdn  = "$root_mo,MeContext=$sgsn_id";
            my $sgsn_file = "$data_dir/A$date.$start_time-${end_time}_${measurement_job}_$ne_version_for{$sgsn_id}_${sgsn_id}.1";

            open my $FH, '>', $sgsn_file or croak("Cannot open file $sgsn_file, $!");
            print {$FH} format_header( $sgsn_fdn, $startdate ), "\n";

            for my $mo_type ( sort keys %formulas_for ) {

                die "MO_TYPE = $mo_type not recognised, check spelling in counters file\n" unless exists $max_instances_for{$mo_type};

                my @counters_list = sort split /:/mx, $counters_for{$mo_type};
                my @fixed_counters_list = @counters_list;
                s/(SM|MM)_/$1./gmx for @fixed_counters_list;
                s/_([GU])/.$1/gmx  for @fixed_counters_list;

                print_measurement_info_start( $FH, $rop_length_in_seconds, $stopdate, @fixed_counters_list );

                for my $moi ( 1 .. $max_instances_for{$mo_type} ) {
                    my $moid = ($mo_type eq 'Sgsn') ? '' : "$moid_for{$mo_type}$moi";  # SGSN has empty moid
                    print_measurement_values( $FH, $moid, \@counters_list, $formulas_for{$mo_type}, \%mo_accumulated, "$sgsn_fdn,$moid", $counter_type_for{$mo_type} );
                }
                print_measurement_info_end($FH);
            }

            print {$FH} format_footer($stopdate), "\n";
            close $FH or croak("Cannot close file $sgsn_file, $!");
        }
    }
}

__END__

$Author: eeikcoy $

$Date: 2007-09-10 10:47:54 +0100 (Mon, 10 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_sgsn_counter_files.pl $

$Id: generate_sgsn_counter_files.pl 53 2007-09-10 09:47:54Z eeikcoy $


=head1 NAME

generate_sgsn_counter_files - creates the ENIQ counter directories and files for SGSN nodes.

=head1 VERSION

This documentation refers to generate_sgsn_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_sgsn_counter_files.pl [options] 

=back

 Example:
        generate_sgsn_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_sgsn_counter_files.pl -t 1000

 will create the ROP files for all counters for 1000.

 Example:
        generate_sgsn_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20 

 will create the ROP files for all counters, for the date range and sgsns given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.
 
 Note that start and end dates must be in the same calendar month.

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

    -n <NEs>, --nes=<NEs>
                number of NEs (sgsns)   [default is 40]
    -s <start_date>, --start_date=<start_date>
                start date             [default is today]
    -e <end_date>, --end_date=<end_date>
                end date               [default is today]
    -t <rop_time>, --time=<rop_time>
                ROP time               [default is all ROP times today]
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 


=head1 DESCRIPTION

This script generates counter directories and files for the SGSN nodes.

This script creates and populates the counter ROP files with sample data.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/sgsn

=item * /eniq/data/pmdata/eniq_oss_1/sgsn/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/sgsn/dir1/A20070906.1345-1400_pm1_R7.0_sgsn01.1

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/sgsn

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/sgsn/RoutingArea.counters

=item * /eniq/home/dcuser/counters/sgsn/Sgsn.counters

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

Ericsson (2007)

