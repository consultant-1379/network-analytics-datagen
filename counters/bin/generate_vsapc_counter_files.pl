#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::ReportsXSD;
use Carp;
use List::Util qw(shuffle);

#use YAML::Tiny;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]
    -n <NEs>, --nes=<NEs>
                number of NEs (SAPCs)   [default is 5]
    -s <start_date>, --start_date=<start_date>
                start date
    -e <end_date>, --end_date=<end_date>
                end date
    -t <rop_time>, --time=<rop_time>
                ROP time
    -o <oss_id>, --oss_id=<oss_id>
                Identity of the OSS collecting the counter files
    -r <rop_length>, --rop=<rop_length>
                ROP length in minutes
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
my $rop_length = 5;                                        # default is 5 minutes
my $oss_id     = 'eniq_oss_1';                             # default is eniq_oss_1
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
   'oss_id=s'     => \$oss_id,
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
   print "Number of SAPCs = $nes\n";
   print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time, $rop_length );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of nodes ($nes) must be > 0\n\n$usage\n\n"                                           if $nes le '0';

my ( $timezone, $not_used, $site, $root_mo ) = get_config_data();

my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/sapc-ecim/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/nodes/vsapc';

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
#print "Constants=[$constants]\n";
eval "$constants" if $constants;                # bring values of constants into local namespace

if ($debug) {
   print "Constants : \n$constants\n" if $constants;
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

# Some constants for SAPC
my $elementType       = 'ERIC-SAPC';
my $swVersion         = '17A';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V10.0';
my %node_version_for  = (
   sapc_03 => '17A',
   sapc_04 => '17A',
   sapc_05 => '17A',
);

my @processors = get_processors();

my @sapc_range = sort keys %node_version_for;

create_pmdata_dirs($data_dir);

my %end_time_for = get_rop_times_5($time, $rop_length);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

# Each counter needs an individual p value in measurement info
my %p_for;
my $p_index = 1;

for my $day_index ( $day_start .. $day_end ) {
   my $day   = add_leading_zero($day_index);
   my $month = add_leading_zero($month_start);

   print "$year_start-$month-$day\n" if $verbose;

   my $date = "$year_start$month$day";    # don't insert / or -, this format is used in ROP file

   for my $start_time ( sort keys %end_time_for ) {
      print "   time = $start_time\n" if $verbose;

      my $end_time = $end_time_for{$start_time};

      for my $sapc_id (@sapc_range) {
         print "      sapc_id  = $sapc_id, version = $node_version_for{$sapc_id}\n" if $verbose;

         my $dnPrefix  = "SubNetwork=ONRM_RootMo,MeContext=$sapc_id";
         my $localDn   = "ManagedElement=$sapc_id";
         my $userLabel = $sapc_id;
          
         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start$month${day}$hours${minutes}00$timezone";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start$month${day}$hours${minutes}00$timezone";

         my $sapc_file = "$data_dir/A$date.$start_time$timezone-${end_time}${timezone}_${sapc_id}_statsfile.xml";
         open my $SAPC_FH, '>', "$sapc_file" or croak "Cannot open file $sapc_file, $!";
         print {$SAPC_FH} format_header_extended( $startdate, $localDn, $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $localDn), "\n";

         for my $mo_type ( sort keys %formulas_for ) {
            print "      mo_type = $mo_type\n" if $verbose;
            
            my @counters_list = sort split /:/mx, $counters_for{$mo_type};
            print "      @counters_list\n" if $debug;

            my %formula_values = get_values_for($formulas_for{$mo_type});

            
            for my $counter (@counters_list) {
               $p_for{$counter} ||= $p_index++; # Save a new p value if it doesn't already exist
               
               my $counter_with_dot = $counter;
               $counter_with_dot =~ s/_/./;
 
               for my $processor (@processors) {
                  my %formula_values = get_values_for($formulas_for{$mo_type});
                  my $counter_value = $formula_values{$counter};
                  my %values = ( "OSProcessingUnit=$processor" => $counter_value );
                  print_measurement_info_with_values( $SAPC_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter_with_dot, $p_for{$counter}, %values );
               }
            }
         }
         
         print {$SAPC_FH} format_footer($stopdate), "\n";
         close $SAPC_FH or croak "Cannot close file $sapc_file, $!";
         
      }
   }
}

#print "P for\n", YAML::Tiny::Dump( \%p_for ) if $debug;

exit 0;

# Subroutines
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

__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_ims_counter_files.pl $

$Id: generate_ims_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_ims_counter_files - creates the ENIQ counter directories and files for IMS nodes.

=head1 VERSION

This documentation refers to generate_ims_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_ims_counter_files.pl [options] 

=back

 Example:
        generate_ims_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_ims_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_ims_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20

 will create the ROP files for all counters, for the date range and IMSs given.

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

=item * /eniq/data/pmdata/eniq_oss_1/ims

=item * /eniq/data/pmdata/eniq_oss_1/ims/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/ims/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=ims07,MeContext=ims07_statsfile.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/ims

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/ims/SAPC.counters

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

