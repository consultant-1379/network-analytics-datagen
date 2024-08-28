#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Carp;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options] 

    -n <NEs>, --nes=<NEs>
                number of NEs (MGWs)   [default is 10]
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
        $0 -s 2007-04-01 -e 2007-04-20 -n 20 

 will create the ROP files for all counters, for the date range and MGWs given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.
 
USAGE

my ( $day_today, $month_today, $year_today ) = get_todays_date();

my $debug      = '';
my $help       = '';
my $verbose    = '';
my $nes        = '10';
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
    print "Start date     = $year_start-$month_start-$day_start\n";
    print "End date       = $year_end-$month_end-$day_end\n";
    print "Number of MGWs = $nes\n";
    print 'ROP time       = ', ($time) ? $time : 'not specified', "\n";
    print "ROP length      = $rop_length\n";
}

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my $year  = $year_start;
my $month = $month_start;

my @mgws = get_ne_list( 'mgw', $nes );

use constant MAX_COUNTER_VALUE => 2**32;    # long integer is 32 bits

my %max_instances_for = (
    IpAccessHostGpb       => 12,            # 0 - 64
    JitterHandlingService => 1,             # 0 - 1
    MgwApplication        => 1,             # 1 - 1
    Mtp2TpAnsi            => 5,             # 0 - 512
    Mtp2TpChina           => 6,             # 0 - 512
    Mtp2TpItu             => 7,             # 0 - 512
    NniSaalTp             => 15,            # 0 - 600
    PlugInUnit            => 1,             # 0 - 1
    RemoteSite            => 3,             # 0 - 127
    TdmTermGrp            => 20,            # 0 - 10000
    Vmgw                  => 8,             # 0 - 32
);

# <parent> in PlugInUnit will be replaced by Subrack=x,Slot=y later
my %moid_for = (
    IpAccessHostGpb       => 'ManagedElement=1,IpSystem=1,IpAccessHostGpb=',
    JitterHandlingService => 'ManagedElement=1,MsProcessing=1,JitterHandlingService=',
    MgwApplication        => 'ManagedElement=1,MgwApplication=',
    Mtp2TpAnsi            => 'ManagedElement=1,TransportNetwork=1,Mtp2TpAnsi=',
    Mtp2TpChina           => 'ManagedElement=1,TransportNetwork=1,Mtp2TpChina=',
    Mtp2TpItu             => 'ManagedElement=1,TransportNetwork=1,Mtp2TpItu=',
    NniSaalTp             => 'ManagedElement=1,TransportNetwork=1,NniSaalTp=',
    PlugInUnit            => 'ManagedElement=1,Equipment=1,<parent>,PlugInUnit=',
    RemoteSite            => 'ManagedElement=1,MgwApplication=1,IpNetwork=1,RemoteSite=',
    TdmTermGrp            => 'ManagedElement=1,MgwApplication=1,TdmTermGrp=',
    Vmgw                  => 'ManagedElement=1,MgwApplication=1,Vmgw=',
);

# assume that all counters in an MO class are of the given type
my %counter_type_for = (
    IpAccessHostGpb       => 'PEG',
    JitterHandlingService => 'PEG',
    MgwApplication        => 'GUAGE',
    Mtp2TpAnsi            => 'PEG',
    Mtp2TpChina           => 'PEG',
    Mtp2TpItu             => 'PEG',
    NniSaalTp             => 'PEG',
    PlugInUnit            => 'GUAGE',
    RemoteSite            => 'PEG',
    TdmTermGrp            => 'PEG',
    Vmgw                  => 'PEG',
);

my %counters_for;
my %formulas_for;
my %mo_accumulated;    # used to hold accumulated running values for MOs with multiple instances

my $data_dir     = "/eniq/data/pmdata/$oss_id/mgw/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/mgw';
my %end_time_for = get_rop_times($time);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
eval "$constants";     # bring values of constants into local namespace

if ($debug) {
    print "Constants : \n$constants\n";
    print "Counters for\n";
    print Dumper(%counters_for);
    print "\nFormulas for\n";
    print Dumper(%formulas_for);
}

create_pmdata_dirs($data_dir);

for my $day_index ( $day_start .. $day_end ) {
    my $day   = add_leading_zero($day_index);
    my $month = add_leading_zero($month);

    print "$year-$month-$day\n" if $verbose;

    my $date = "$year$month$day";    # don't insert / or -, this format is used in ROP file

    for my $start_time ( sort keys %end_time_for ) {
        print "   time = $start_time\n" if $verbose;

        my $end_time = $end_time_for{$start_time};

        for my $mgw_id (@mgws) {
            print "      mgw_id = $mgw_id\n" if $verbose;

            my $startdate = "$date${start_time}00$timezone";
            my $stopdate  = "$date${end_time}00$timezone";

            my $mgw_fdn = "$root_mo,MeContext=$mgw_id";
            my $mgw_file;
            if ( defined $ENV{OS} ) {    # If OS is defined the system is Windows, and it can't handle : (colon) in a filename.
                $mgw_file = "$data_dir/A$date.$start_time-${end_time}_${mgw_id}.xml";    # see p6 MGW User Guide 17/1553-AXM 101 01/5 Rev C
            }
            else {
                $mgw_file = "$data_dir/A$date.$start_time-${end_time}_${mgw_id}:1.xml";    # see p6 MGW User Guide 17/1553-AXM 101 01/5 Rev C
            }

            open my $FH, '>', $mgw_file or croak "Cannot open file $mgw_file, $!";
            print {$FH} format_header( $mgw_fdn, $startdate ), "\n";

            for my $mo_type ( sort keys %formulas_for ) {
                die "MO_TYPE = $mo_type not recognised, check spelling in counters file\n" unless exists $max_instances_for{$mo_type};

                my @counters_list = sort split /:/mx, $counters_for{$mo_type};
                print_measurement_info_start( $FH, $rop_length_in_seconds, $stopdate, @counters_list );

                my @parent_mos = (1);                                                      # default is that there is only one parent MO
                if ( $mo_type =~ m/^PlugInUnit$/mx ) {
                    my @subracks = 1 .. 4;                                                 # each of 4 Subracks can have a Slot
                    my @slots    = 1 .. 28;                                                # each of 28 Slots can have a PlugInUnit
                    @parent_mos = ();                                                      # reset list
                    for my $subrack (@subracks) {
                        for my $slot (@slots) {
                            push @parent_mos, "Subrack=$subrack,Slot=$slot";
                        }
                    }
                }

                for my $parent_mo (@parent_mos) {
                    for my $moi ( 1 .. $max_instances_for{$mo_type} ) {
                        my $moid = "$moid_for{$mo_type}$moi";
                        $moid =~ s/<parent>/$parent_mo/mx;                                 # if a parent exists, then replace the placeholder here. The placeholder is specified in the definition of the %moid_for hash.
                        print_measurement_values( $FH, $moid, \@counters_list, $formulas_for{$mo_type}, \%mo_accumulated, "$mgw_fdn,$moid", $counter_type_for{$mo_type} );
                    }
                }
                print_measurement_info_end($FH);
            }

            print {$FH} format_footer($stopdate), "\n";
            close $FH or croak "Cannot close file $mgw_file, $!";
        }
    }
}

__END__

$Author: eeikcoy $

$Date: 2007-09-10 10:47:54 +0100 (Mon, 10 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_mgw_counter_files.pl $

$Id: generate_mgw_counter_files.pl 53 2007-09-10 09:47:54Z eeikcoy $


=head1 NAME

generate_mgw_counter_files - creates the ENIQ counter directories and files for M-MGw nodes.

=head1 VERSION

This documentation refers to generate_mgw_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_mgw_counter_files.pl [options] 

=back

 Example:
        generate_mgw_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_mgw_counter_files.pl -t 1000

 will create the ROP files for all counters for 1000.

 Example:
        generate_mgw_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20 

 will create the ROP files for all counters, for the date range and MGws given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.
 
 Note that start and end dates must be in the same calendar month.

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

    -n <NEs>, --nes=<NEs>
                number of NEs (MGWs)   [default is 10]
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

This script generates counter directories and files for the M-MGw nodes.

This script creates and populates the counter ROP files with sample data.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/mgw

=item * /eniq/data/pmdata/eniq_oss_1/mgw/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/mgw/dir1/A20070906.1145-1200_mgw01:1.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/mgw

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/mgw/IpAccessHostGpb.counters

=item * /eniq/home/dcuser/counters/mgw/JitterHandlingService.counters

=item * /eniq/home/dcuser/counters/mgw/MgwApplication.counters

=item * /eniq/home/dcuser/counters/mgw/Mtp2TpAnsi.counters

=item * /eniq/home/dcuser/counters/mgw/Mtp2TpChina.counters

=item * /eniq/home/dcuser/counters/mgw/Mtp2TpItu.counters

=item * /eniq/home/dcuser/counters/mgw/NniSaalTp.counters

=item * /eniq/home/dcuser/counters/mgw/PlugInUnit.counters

=item * /eniq/home/dcuser/counters/mgw/RemoteSite.counters

=item * /eniq/home/dcuser/counters/mgw/TdmTermGrp.counters

=item * /eniq/home/dcuser/counters/mgw/Vmgw.counters

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

