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
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -r <rop_length>, --rop_length=<rop_length>
                ROP length
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information 

 Example:
        $0 

 will create the ROP files for all counters in the input files.

 Example:
        $0 -s 2007-04-01 -e 2007-04-20 -r 20

 will create the ROP files for all counters in the input files, for the date range.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.

USAGE

my ( $day_today, $month_today, $year_today ) = get_todays_date();

my $debug      = '';
my $help       = '';
my $verbose    = '';                                       # default is off
my $time       = '';
my $rop_length = '';
my $start_date = "$year_today-$month_today-$day_today";    # default is today
my $end_date   = $start_date;                              # default is today

GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
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

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;

my ($node_type) = $0 =~ m/generate_(\w+)_counter_files/; # extract the node type from the calling script name
print "node_type = $node_type\n" if $debug;
my %config = get_configuration_data($node_type);

if ($verbose) {
   print "Start date      = $year_start-$month_start-$day_start\n";
   print "End date        = $year_end-$month_end-$day_end\n";
   print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

for my $node_id (keys %config) {
   my %counters_for;
   my %formulas_for;

   my $output_dir = "/eniq/data/pmdata/$config{$node_id}{OSS_ID}/$config{$node_id}{OUTPUT_DIR}/dir1";
   my $rop_period = ($rop_length) ? $rop_length : $config{$node_id}{ROP_LENGTH}; # use ROP length from command argument if given, else use value from config file
   print "rop_period = $rop_period\n" if $debug;

   my $constants = read_counters( $config{$node_id}{COUNTERS_DIR}, \%counters_for, \%formulas_for );
   eval "$constants" if $constants; # bring values of constants into local namespace

   if ($debug) {
      print "Constants : \n$constants\n" if $constants;
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
   }

   create_pmdata_dirs($output_dir);

   my %end_time_for = get_rop_times($time);
   my $rop_length_in_seconds = $rop_period * 60; # file details need ROP length in seconds

   for my $day_index ( $day_start .. $day_end ) {
      my $day   = add_leading_zero($day_index);
      my $month = add_leading_zero($month_start);

      print "$year_start-$month-$day\n" if $verbose;

      my $date = "$year_start$month$day";

      for my $start_time ( sort keys %end_time_for ) {
         print "   time = $start_time\n" if $verbose;
         my $end_time = $end_time_for{$start_time};
         print "      node_id = $node_id\n" if $verbose;

         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$config{$node_id}{TIMEZONE}";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$config{$node_id}{TIMEZONE}";
         my $dnPrefix  = "";
         my $localDn   = "ManagedElement=$node_id";
         my $node_file = "$output_dir/A$date.$start_time$config{$node_id}{TIMEZONE}-$end_time$config{$node_id}{TIMEZONE}_${node_id}_epg";

         open my $NODE_FH, '>', "$node_file" or croak "Cannot open file $node_file, $!";
         print {$NODE_FH} format_header_extended( $startdate, $localDn, $config{$node_id}{USER_LABEL}, $config{$node_id}{SW_VERSION}, $dnPrefix, $config{$node_id}{ELEMENT_TYPE}, $config{$node_id}{VENDOR_NAME}, $config{$node_id}{FILE_FORMAT_VERSION}, $localDn), "\n";

         for my $mo_type ( sort keys %formulas_for ) {
            my $measObjLdn    = $mo_type;            
            my @counters_list = sort split /:/mx, $counters_for{$mo_type};

            print "      mo_type    = $mo_type\n"    if $verbose;
            print "      measObjLdn = $measObjLdn\n" if $verbose;

            my @measured_objects;
            if ($mo_type eq 'ggsnApnStats') {
#               print "      APN_LIST = $config{$node_id}{APN_LIST}\n" if $verbose;
               my @apn_list = split ',', $config{$node_id}{APN_LIST};
               
               for my $apn (@apn_list) {
                  push @measured_objects, "$measObjLdn,ggsnApnName=$apn";
               }
            }
            else {
               push @measured_objects, $measObjLdn;
            }

            for my $measured_object (@measured_objects) {
               print_measurement_info_start( $NODE_FH, $rop_length_in_seconds, $stopdate, @counters_list );
               print_measurement_values( $NODE_FH, $measured_object, \@counters_list, $formulas_for{$mo_type} );
               print_measurement_info_end($NODE_FH);
            }
         }

         print {$NODE_FH} format_footer($stopdate), "\n";
         close $NODE_FH or croak "Cannot close file $node_file, $!";
      }
   }
}

__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_GGSN_counter_files.pl $

$Id: generate_GGSN_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_GGSN_counter_files - creates the ENIQ counter directories and files for GGSN nodes.

=head1 VERSION

This documentation refers to generate_GGSN_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_GGSN_counter_files.pl [options] 

=back

 Example:
        generate_GGSN_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_GGSN_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_GGSN_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20

 will create the ROP files for all counters, for the date range and GGSNs given.

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

=item * /eniq/data/pmdata/eniq_oss_1/GGSN

=item * /eniq/data/pmdata/eniq_oss_1/GGSN/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/GGSN/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=GGSN07,MeContext=GGSN07_statsfile.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/GGSN

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/GGSN/CSCF.counters

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

