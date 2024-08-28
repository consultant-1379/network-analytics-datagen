#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Encoding::BER;
use Carp;
use Data::Dumper;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]
    -n <NEs>, --nes=<NEs>
                number of NEs (AXEs)   [default is 5]
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -f, --file
                dump measurement data to a text file
    -o <oss_id>, --oss_id=<oss_id>
                Identity of the OSS collecting the counter files
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
my $axe_type   = 'msc';                                    # default is MSC
my $nes        = '5';                                      # default is 5
my $cells      = '50';                                     # default is 50
my $time       = '';                                       # default is empty string, i.e. produce all 96 ROPs per day
my $start_date = "$year_today-$month_today-$day_today";    # default is today
my $end_date   = $start_date;                              # default is today
my $file       = '';
my $oss_id     = 'eniq_oss_1';                             # default is eniq_oss_1

GetOptions(
    'debug'        => \$debug,
    'help'         => \$help,
    'verbose'      => \$verbose,
    'axe_type=s'   => \$axe_type,
    'nes=s'        => \$nes,
    'cells=s'      => \$cells,
    'start_date=s' => \$start_date,
    'end_date=s'   => \$end_date,
    'time=s'       => \$time,
    'file'         => \$file,
    'oss_id=s'     => \$oss_id,
);

if ($help) {
    print "$usage\n\n\n";
    exit;
}

my ( $timezone, $not_used, $site, $root_mo ) = get_config_data();

my ( $year_start, $month_start, $day_start ) = get_date_ymd($start_date);
my ( $year_end,   $month_end,   $day_end )   = get_date_ymd($end_date);

$axe_type = lc $axe_type;

if ($verbose) {
    print "Start date      = $year_start-$month_start-$day_start\n";
    print "End date        = $year_end-$month_end-$day_end\n";
    print "AXE type        = $axe_type\n";
    print "Number of NEs   = $nes\n";
    print "Number of cells = $cells\n";
    print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
}

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nAXE type ($axe_type) not valid, must be either BSC or MSC\n\n$usage\n\n" unless $axe_type =~ m/^(BSC|MSC)$/imx;
die "\nNumber of NEs ($nes) must be > 0\n\n$usage\n\n"     if $nes le '0';
die "\nNumber of cells ($cells) must be > 0\n\n$usage\n\n" if $cells le '0';

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

my $year  = $year_start;
my $month = $month_start;

my %dir_for_axe_type = (
    bsc => 'bsc-iog',
    msc => 'msc-iog',
);

my @nes = get_ne_list( "${axe_type}_", $nes );
my @cells = get_ne_list( 'cell', $cells );

if ( scalar @cells < 100 ) {
    s/cell/cell0/mx for @cells;    # hack to rename cells (e.g. cell001 instead of cell01) if <100 requested
}

my @cells_with_neighbours = ( 'cell001' .. 'cell005' );    # only need a subset of all cells here

my %cell_objects = (
    CELLCCHDR  => '',
    CELLEIT2   => '',
    CELLGPRS   => '',
    CELLGPRS2  => '',
    CELLGPRS3  => '',
    CELLQOS    => '',
    CELLQOSG   => '',
    CELLQOSGEG => '',
    CELLSQI    => '',
    CELLSQIDL  => '',
    CELTCHF    => '',
    CELTCHH    => '',
    CLDTMQOS   => '',
    CLSDCCH    => '',
    CLSDCCHO   => '',
    CLTCH      => '',
    CLTCHDRF   => '',
    CLTCHDRH   => '',
    RANDOMACC  => '',
    RLINKBITR  => '',
    TRAFDLGPRS => '',
    TRAFGPRS2  => '',
    TRAFGPRS3  => '',
    TRAFULGPRS => '',
);

my %cell_relation_objects = (
    NCELLREL  => '',
    NECELASS  => '',
    NECELLREL => '',
    NICELASS  => '',
    NUCELLREL => '',
);

my %counters_for;
my %formulas_for;
my %values_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/$dir_for_axe_type{$axe_type}/dir1";
my $counters_dir = "/eniq/home/dcuser/counters/$axe_type";

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
eval "$constants" if $constants;    # bring values of constants into local namespace

if ($debug) {
    print "Constants : \n$constants\n" if $constants;
    print "Counters for\n";
    print Dumper(%counters_for);
    print "\nFormulas for\n";
    print Dumper(%formulas_for);
}

create_pmdata_dirs($data_dir);

my %end_time_for = get_rop_times($time);

my $enc = Encoding::BER->new();
add_tags($enc);    # add custom ASN.1 tags for PM counters

my $vendor       = 'Ericsson';
my $ne_user_name = 'BO Reports Data';

for my $day_index ( $day_start .. $day_end ) {
    my $day   = add_leading_zero($day_index);
    my $month = add_leading_zero($month);

    print "$year-$month-$day\n" if $verbose;

    my $date = "$year$month$day";    # don't insert / or -, this format is used in ROP file

    for my $start_time ( sort keys %end_time_for ) {
        print "   time = $start_time\n" if $verbose;

        my $end_time = $end_time_for{$start_time};

        my $start_datetime  = "$date${start_time}00$timezone";
        my $stop_datetime   = "$date${end_time}00$timezone";
        my $collection_time = $start_datetime;                   # should be at least 15 minutes prior to start time, but it isn't used in ENIQ so just set to start time

        for my $ne_id (@nes) {
            print "      ne_id = $ne_id\n" if $verbose;

            my $ne_distinguished_name = "Exchange Identity=$ne_id,Object Type=$ne_id";

            my $meas_info = meas_info_header();

            for my $object_type ( sort keys %formulas_for ) {
                my @instances = ('-');                           # default is no instances
                if ( $object_type eq 'MTRAFTYPE' ) {
                    @instances = qw(ORG IEX OEX TE);             # 4 Traffic types
                }
                elsif ( $object_type eq 'TRUNKROUTE' ) {
                    @instances = ( 1 .. 10 );
                }
                elsif ( $object_type eq 'MMESTAT' ) {
                    @instances = qw( sgsn_mme_01 sgsn_mme_02 sgsn_mme_03 );
                }
                elsif ( exists $cell_objects{$object_type} ) {    # object is a Cell Object
                    @instances = map { "$ne_id$_" } @cells;
                }
                elsif ( exists $cell_relation_objects{$object_type} ) {    # object is a Cell Relation Object
                    @instances = ();
                    if ( $object_type eq 'NUCELLREL' ) {                   # special handling for UTRAN cell relations
                        for my $cell (@cells_with_neighbours) {
                            @instances = ( @instances, map { "$ne_id$cell-rnc01$_" } @cells_with_neighbours );
                        }
                    }
                    else {                                                 # handle BSC cell relations
                        for my $cell (@cells_with_neighbours) {
                            for my $cell_neighbour ( @cells_with_neighbours ) {
                               push @instances, "$ne_id$cell-$ne_id$cell_neighbour" unless $cell eq $cell_neighbour;
                            }
                        }
                    }
                }

                for my $instance (@instances) {
                    eval "$formulas_for{$object_type}";                    # set measurement values in values_for hash

                    # create a stringified version of an array of anonymous hashes containing measurement types
                    my @meas_types = map { "{'type' => 'graphic_string', 'value' => '$_'}," } sort keys %values_for;

                    # create a stringified version of an array of anonymous hashes containing measurement values
                    my @meas_values = map { "{ 'type' => 'neValue', 'value' => $values_for{$_} }," } sort keys %values_for;

                    if ($debug) {
                        print "\nValues for $object_type\n";
                        print Dumper(%values_for);
                        print "\nMeas_types\n";
                        print "@meas_types";
                        print Dumper(@meas_types);
                        print "\nMeas_values\n";
                        print "@meas_values";
                        print Dumper(@meas_values);
                    }

                    $meas_info .= meas_info_body( $start_datetime, "$object_type.$instance", "[@meas_types]", "[@meas_values]" );

                    %values_for = ();    # set hash to empty
                }
            }

            $meas_info .= meas_info_footer();

            my $meas_data = meas_data_header( $ne_user_name, $ne_distinguished_name ) . $meas_info . meas_data_footer();

            my $meas_data_collection = meas_file_header( $ne_id, $axe_type, $vendor, $collection_time ) . $meas_data . meas_file_footer($start_datetime);

            if ($debug) {
                print "\nMeas_data_collection\n";
                print $meas_data_collection;
            }

            my $ber = $enc->encode( eval "$meas_data_collection" );

            my $ne_file;
            if ( defined $ENV{OS} ) {    # If OS is defined the system is Windows, and it can't handle : (colon) in a filename.
                $ne_file = "$data_dir/A$date.$start_time-$date.${end_time}_${ne_id}";    # DOS doesn't handle :1 in file names
            }
            else {
                $ne_file = "$data_dir/A$date.$start_time-$date.${end_time}_${ne_id}:1";
            }

            # Save as text file or ASN.1 encoded depending on command line --file option, default is ASN.1
            if ($file) {
               open my $TEXT_FH, '>', "$ne_file" or croak "Cannot open file $ne_file, $!";
               print {$TEXT_FH} $meas_data_collection;
               close $TEXT_FH or croak "Cannot close file $ne_file, $!";
            } else {          
               open my $NE_FH, '> :raw', "$ne_file" or croak "Cannot open file $ne_file, $!";
               print {$NE_FH} $ber;
               close $NE_FH or croak "Cannot close file $ne_file, $!";
            }
        }
    }
}

sub meas_file_header {
    my ( $ne_id, $axe_type, $vendor, $collection_time ) = @_;
    return <<"MEASFILEHEADER"
[
    {
        type => 'measFileHeader',
        value => 
            [                  
                {
                    type  => 'fileFormatVersion',
                    value => 1
                },
                {
                    type  => 'senderName',
                    value => '$ne_id'
                },
                {
                    type  => 'senderType',
                    value => '$axe_type'
                },
                {
                    type  => 'vendorName',
                    value => '$vendor'
                },
                {
                    type  => 'collectionBeginTime',
                    value => '$collection_time'
                },
            ]      
    },
MEASFILEHEADER
}

sub meas_file_footer {
    my ($start_time) = @_;
    return <<"MEASFILEFOOTER";
    {         
        type => 'measFileFooter',
        value => '$start_time'
    }
]
MEASFILEFOOTER
}

sub meas_data_header {
    my ( $ne_user_name, $ne_distinguished_name ) = @_;
    return <<"MEASDATAHEADER";
    {         
        type => 'measData',
        value => 
            [ 
                [
                    {
                        type => 'nEId',
                        value => 
                            [
                                {
                                    type  => 'nEUserName',
                                    value => '$ne_user_name'
                                },
                                { 
                                    type  => 'nEDistinguishedName',
                                    value => '$ne_distinguished_name'                   
                                }
                            ]
                    },
MEASDATAHEADER
}

sub meas_data_footer {

    return <<'MEASDATAFOOTER';
                 ]
            ]
    },
MEASDATAFOOTER
}

sub meas_info_header {
    return <<'MEASINFOHEADER';
                    {
                        type => 'measInfo',
                        value => 
                            [
MEASINFOHEADER
}

sub meas_info_footer {
    return <<'MEASINFOFOOTER';
                            ],
                    },
MEASINFOFOOTER
}

sub meas_info_body {
    my ( $start_time, $object_type, $meas_types, $meas_values ) = @_;
    return <<"MEASINFO";
                              [
                                {
                                    type  => 'measTimeStamp',
                                    value => '$start_time'
                                },
                                { 
                                    type  => 'granularityPeriod',
                                    value => 900                  
                                },
                                {
                                     type => 'measTypes',
                                     value => $meas_types
                                },
                                {
                                     type => 'measValues',
                                     value => 
                                        [
                                          [
                                            {
                                                type  => 'measObjInstId',
                                                value => '$object_type'
                                            },
                                            {
                                                type  => 'measResults',
                                                value => $meas_values
                                            },
                                            {
                                                type  => 'suspectFlag',
                                                value => ''
                                            }
                                          ]
                                        ]                                      
                                },

                              ],
MEASINFO
}

sub add_tags {
    my $enc = shift;
    $enc->add_implicit_tag( 'context', 'constructed', 'measFileHeader', 0, 'sequence' );
    $enc->add_implicit_tag( 'context', 'constructed', 'measData',       1, 'sequence' );
    $enc->add_implicit_tag( 'context', 'constructed', 'nEId',           0, 'sequence' );

    $enc->add_implicit_tag( 'context', 'primitive',   'measFileFooter', 2, 'octet_string' );
    $enc->add_implicit_tag( 'context', 'constructed', 'measInfo',       1, 'sequence' );

    $enc->add_implicit_tag( 'context', 'constructed', 'measTypes',  2, 'sequence' );
    $enc->add_implicit_tag( 'context', 'constructed', 'measValues', 3, 'sequence' );

    $enc->add_implicit_tag( 'context', 'primitive', 'fileFormatVersion',   0, 'integer' );
    $enc->add_implicit_tag( 'context', 'primitive', 'senderName',          1, 'octet_string' );
    $enc->add_implicit_tag( 'context', 'primitive', 'senderType',          2, 'octet_string' );
    $enc->add_implicit_tag( 'context', 'primitive', 'vendorName',          3, 'octet_string' );
    $enc->add_implicit_tag( 'context', 'primitive', 'collectionBeginTime', 4, 'octet_string' );

    $enc->add_implicit_tag( 'context', 'primitive', 'nEUserName',          0, 'octet_string' );
    $enc->add_implicit_tag( 'context', 'primitive', 'nEDistinguishedName', 1, 'octet_string' );

    $enc->add_implicit_tag( 'context', 'primitive', 'measTimeStamp',     0, 'octet_string' );
    $enc->add_implicit_tag( 'context', 'primitive', 'granularityPeriod', 1, 'integer' );

    $enc->add_implicit_tag( 'context', 'primitive', 'neValue',       0, 'integer' );
    $enc->add_implicit_tag( 'context', 'primitive', 'measObjInstId', 0, 'octet_string' );

    $enc->add_implicit_tag( 'context', 'constructed', 'measResults', 1, 'sequence' );

    $enc->add_implicit_tag( 'context', 'primitive', 'suspectFlag', 2, 'boolean' );

    return;
}

__END__

$Author: eeikcoy $

$Date: 2007-09-06 13:46:46 +0100 (Thu, 06 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_axe_counter_files.pl $

$Id: generate_axe_counter_files.pl 49 2007-09-06 12:46:46Z eeikcoy $


=head1 NAME

generate_axe_counter_files - creates the ENIQ counter directories and files for AXE nodes, i.e. MSC and BSC.

=head1 VERSION

This documentation refers to generate_axe_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_axe_counter_files.pl [options] 

=back

 Example:
        generate_axe_counter_files.pl 

 will create the ROP files for all counters for today (for BSC by default).

 Example:
        generate_axe_counter_files.pl -a msc

 will create the ROP files for all counters for today for MSC.

 Example:
        generate_axe_counter_files.pl -a bsc -t 0945

 will create the ROP files for all counters for time 0945.

 Example:
        generate_axe_counter_files.pl -a msc -s 2007-04-01 -e 2007-04-20 -n 20 

 will create the ROP files for all counters, for the date range and NEs given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.
 
 Note that start and end dates must be in the same calendar month.

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

    -a <axe_type>, --axe_type=<axe_type>
                AXE type, e.g. BSC, MSC, etc.  [default is BSC]
    -n <NEs>, --nes=<NEs>
                number of NEs [default is 10]
    -c <cells>, --cells=<cells>
                number of cells per BSC [default is 100]
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

This script generates counter directories and files for the MSC and BSC nodes.

This script creates and populates the counter ROP files with sample data.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/bsc-iog

=item * /eniq/data/pmdata/eniq_oss_1/bsc-iog/dir1

=item * /eniq/data/pmdata/eniq_oss_1/msc-iog

=item * /eniq/data/pmdata/eniq_oss_1/msc-iog/dir1

=back

=head2 Counter Files

=head3 BSC

The counter topology files are stored in the dir1 directory, example files are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/bsc-iog/dir1/A20070906.1315-20070906.1330_bsc03:1

=back


=head3 MSC

The counter topology files are stored in the dir1 directory, example files are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/msc-iog/dir1/A20070906.1330-20070906.1345_msc01:1

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

=head3 BSC

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/bsc

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/bsc/CELLGPRS.counters

=item * /eniq/home/dcuser/counters/bsc/CELLCCHDR.counters

=item * /eniq/home/dcuser/counters/bsc/NICELASS.counters

=item * /eniq/home/dcuser/counters/bsc/CELLSQI.counters

=item * /eniq/home/dcuser/counters/bsc/TRAFGPRS3.counters

=item * /eniq/home/dcuser/counters/bsc/CLTCHDRF.counters

=item * /eniq/home/dcuser/counters/bsc/CELTCHH.counters

=item * /eniq/home/dcuser/counters/bsc/CLDTMQOS.counters

=item * /eniq/home/dcuser/counters/bsc/CELLQOSG.counters

=item * /eniq/home/dcuser/counters/bsc/CELLQOSGEG.counters

=item * /eniq/home/dcuser/counters/bsc/CELLQOS.counters

=item * /eniq/home/dcuser/counters/bsc/CLTCHDRH.counters

=item * /eniq/home/dcuser/counters/bsc/TRAFGPRS2.counters

=item * /eniq/home/dcuser/counters/bsc/CELTCHF.counters

=item * /eniq/home/dcuser/counters/bsc/NECELASS.counters

=item * /eniq/home/dcuser/counters/bsc/CLTCH.counters

=item * /eniq/home/dcuser/counters/bsc/RANDOMACC.counters

=item * /eniq/home/dcuser/counters/bsc/CLSDCCH.counters

=item * /eniq/home/dcuser/counters/bsc/CELLEIT2.counters

=item * /eniq/home/dcuser/counters/bsc/CELLGPRS3.counters

=item * /eniq/home/dcuser/counters/bsc/TRAFDLGPRS.counters

=item * /eniq/home/dcuser/counters/bsc/CLSDCCHO.counters

=item * /eniq/home/dcuser/counters/bsc/NUCELLREL.counters

=item * /eniq/home/dcuser/counters/bsc/CELLSQIDL.counters

=item * /eniq/home/dcuser/counters/bsc/NCELLREL.counters

=item * /eniq/home/dcuser/counters/bsc/NECELLREL.counters

=item * /eniq/home/dcuser/counters/bsc/TRAFULGPRS.counters

=item * /eniq/home/dcuser/counters/bsc/CELLGPRS2.counters

=item * /eniq/home/dcuser/counters/bsc/RLINKBITR.counters

=back

=head3 MSC

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/msc

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/msc/UGHNDOVER.counters

=item * /eniq/home/dcuser/counters/msc/MTRAFTYPE.counters

=item * /eniq/home/dcuser/counters/msc/NBRMSCLST.counters

=item * /eniq/home/dcuser/counters/msc/TRUNKROUTE.counters

=item * /eniq/home/dcuser/counters/msc/GUHNDOVER.counters

=item * /eniq/home/dcuser/counters/msc/L3CCMSG.counters

=item * /eniq/home/dcuser/counters/msc/UPDLOCAT.counters

=item * /eniq/home/dcuser/counters/msc/NBRMSCSRNS.counters

=item * /eniq/home/dcuser/counters/msc/UMTSSEC.counters

=item * /eniq/home/dcuser/counters/msc/LOAS.counters

=item * /eniq/home/dcuser/counters/msc/RNCSTAT.counters

=item * /eniq/home/dcuser/counters/msc/SECHAND.counters

=item * /eniq/home/dcuser/counters/msc/SHMSGSERV.counters

=item * /eniq/home/dcuser/counters/msc/PAGING.counters

=item * /eniq/home/dcuser/counters/msc/CHASSIGNT.counters

=item * /eniq/home/dcuser/counters/msc/NBRMSCUGHO.counters

=item * /eniq/home/dcuser/counters/msc/NBRMSCGUH.counters

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

