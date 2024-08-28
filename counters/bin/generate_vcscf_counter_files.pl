#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::ReportsXSD;
use Carp;
use List::Util qw(shuffle);

use YAML::Tiny;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]
    -n <NEs>, --nes=<NEs>
                number of NEs (CSCFs)   [default is 5]
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
my $oss_id     = 'eniq_oss_2';                             # default is eniq_oss_1
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
   print "Number of CSCFs = $nes\n";
   print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time, $rop_length );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of nodes ($nes) must be > 0\n\n$usage\n\n"                                            if $nes le '0';

my ( $timezone, $not_used, $site, $root_mo ) = get_config_data();

my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/cscf/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/nodes/vcscf';

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
#print "Constants=[$constants]\n";
eval "$constants" if $constants;                # bring values of constants into local namespace

if ($debug) {
   print "Constants : \n$constants\n" if $constants;
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

# Some constants for CSCF
my $elementType       = 'CSCF';
my $swVersion         = '17A';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V10.0';
my $node_name_prefix  = 'CSCF_g3ManagedElement=';
my %node_version_for  = (
   cscf_20 => '17A',
#   cscf_21 => '17A',
#   cscf_22 => '17A',
   cscf_23 => '17A',
#   cscf_24 => '17A',
   cscf_25 => '17B',
   cscf_26 => '17B',
#   cscf_27 => '17B',
#   cscf_28 => '17B',
   cscf_29 => '17B',
);

my @cscf_range = sort keys %node_version_for;

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

      for my $cscf_id (@cscf_range) {
         print "      cscf_id  = $cscf_id, version = $node_version_for{$cscf_id}\n" if $verbose;

         my $dnPrefix  = "DC=ims.ericsson.se,g3SubNetwork=IMS,g3ManagedElement=$cscf_id";
         my $localDn   = "g3ManagedElement=$cscf_id";
         my $userLabel = $cscf_id;
          
         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$timezone";

         my $cscf_file = "$data_dir/A$date.$start_time$timezone-${end_time}${timezone}_$node_name_prefix${cscf_id}_statsfile.xml";           

         open my $CSCF_FH, '>', "$cscf_file" or croak "Cannot open file $cscf_file, $!";
         print {$CSCF_FH} format_header_extended( $startdate, $localDn, $userLabel, $node_version_for{$cscf_id}, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $localDn), "\n";

         for my $mo_type ( sort keys %formulas_for ) {
            print "      mo_type = $mo_type\n" if $verbose;
            my $measObjLdn = $mo_type;
            
            if ($mo_type eq 'CscfRegistrationStatistics') {                           
               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               print "      @counters_list\n" if $debug;

               my @selected_access_types = get_selection_of_access_types();
               my %formula_values        = get_values_for($formulas_for{$mo_type});

               for my $counter (@counters_list) {
                  my $counter_value = $formula_values{$counter};
                  print "      $counter = $counter_value\n" if $debug;
                  $p_for{$counter} ||= $p_index++; # Save a new p value if it doesn't already exist
                  
                  my %values;

                  if ($counter =~ m/Accepted|Profiles|Success$/) {
                     %values = ( DEFAULT => $counter_value );
                  } elsif ($counter =~ m/[Rr]egistrationFailure$/) {
                     %values = get_counter_values_per_response_code('', $counter_value, ''); # These counters use only numerical codes
                  } elsif ($counter =~ m/Failure$/) {
                     %values = get_counter_values_per_response_code('', $counter_value, 'SipResponse='); # These counters use SipResponse=<numerical code>
                  } elsif ($counter =~ m/(Successful|Attempted).*PerAccess$/) {
                     for my $access_type (@selected_access_types) {
                        print "access type = $access_type\n" if $debug;
                        %values = ( "AccessType=$access_type, DEFAULT" => $counter_value );
                     }
                  } elsif ($counter =~ m/Failed.*PerAccess$/) {
                     for my $access_type (@selected_access_types) {
                        print "access type = $access_type\n" if $debug;
                        %values = get_counter_values_per_response_code($access_type, $counter_value, 'SipResponse='); # These counters use AccessType=<access code>, SipResponse=<numerical code>
                     }
                  }

                  print_measurement_info_with_values( $CSCF_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter, $p_for{$counter}, %values );
               }

            } elsif ($mo_type eq 'CscfSession' or $mo_type eq 'CscfEmergency' or $mo_type eq 'CscfCxIfStatistics') {
               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               print "      @counters_list\n" if $debug;

               my @selected_access_types = get_selection_of_access_types();

               for my $access_type (@selected_access_types) {
                  print "access type = $access_type\n" if $debug;
                  my %formula_values = get_values_for($formulas_for{$mo_type});

                  for my $counter (@counters_list) {
                     my $counter_value = $formula_values{$counter};
                     print "      $counter = $counter_value\n" if $debug;
                     $p_for{$counter} ||= $p_index++; # Save a new p value if it doesn't already exist
                     
                     my %values;

                     if ($counter =~ m/Successful|Attempted|Attempts|Received|Success/) {
                        %values = ( "$access_type, DEFAULT" => $counter_value );                       
                     } elsif ($counter =~ m/Failed/) {
                        %values = get_counter_values_per_response_code($access_type, $counter_value, 'SipResponse='); # These counters use AccessType=<access code>, SipResponse=<numerical code>
                     }
                     
                     print_measurement_info_with_values( $CSCF_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter, $p_for{$counter}, %values );
                  }
               }
            }
         }

         print {$CSCF_FH} format_footer($stopdate), "\n";
         close $CSCF_FH or croak "Cannot close file $cscf_file, $!";
         
      }
   }
}

print "P for\n", YAML::Tiny::Dump( \%p_for ) if $debug;


#
#
# Subroutines
#
#


sub get_selection_of_access_types {

   my @access_types = qw(
3GPP-E-UTRAN-FDD
3GPP-E-UTRAN-TDD
3GPP-GERAN
3GPP-UTRAN-FDD
3GPP-UTRAN-TDD
3GPP2-1X
3GPP2-1X-Femto
3GPP2-1X-HRPD
3GPP2-UMB
ADSL
ADSL2
ADSL2+
DOCSIS
G.SHDSL
HDSL
HDSL2
IDSL
IEEE-802.11
IEEE-802.11a
IEEE-802.11b
IEEE-802.11g
IEEE-802.11n
IEEE-802.3
IEEE-802.3a
IEEE-802.3ab
IEEE-802.3ae
IEEE-802.3ah
IEEE-802.3ak
IEEE-802.3an
IEEE-802.3aq
IEEE-802.3e
IEEE-802.3i
IEEE-802.3j
IEEE-802.3u
IEEE-802.3y
IEEE-802.3z
DVB-RCS2
RADSL
SDSL
VDSL
);

   my @wifi_access_types = grep { m/IEEE/ } @access_types;

   my $wifi_access_types_count = int( rand($#wifi_access_types));
   $wifi_access_types_count    = 1 if $wifi_access_types_count == 0; # ensure at least one

   print "      wifi_access_types_count = $wifi_access_types_count\n" if $debug;
   
   my @selected_access_types = shuffle(@wifi_access_types);
   @selected_access_types = splice(@selected_access_types, -$wifi_access_types_count);  # take random number of access types

   return @selected_access_types;
}

                           
sub get_counter_values_per_response_code {
   my ($access_type, $counter_value, $sip_prefix) = @_;
  
   my @failure_responses = qw(400 401 403 404 407 484 486 500 503 600);
   
   # If Access Type is defined, then add a prefix to the MOID key
   my $prefix ||= $sip_prefix;
   $prefix = "AccessType=$access_type, $sip_prefix" if $access_type;

   # Set the SUM to the total counter value
   my %values = (
      "SUM" => $counter_value,
   );

   my $failure_responses_count = int( rand($#failure_responses));
   $failure_responses_count    = 1 if $failure_responses_count == 0; # ensure at least one

   print "      failure_responses_count = $failure_responses_count\n" if $debug;

   my @shuffled_failure_responses = shuffle(@failure_responses);
   my @random_failure_responses = splice(@shuffled_failure_responses, -$failure_responses_count);  # take random number of failure responses

   my $running_count = $counter_value; # keep a total of allocated counter values and allocate the remainder to the first failure_response at the end. There can be significant rounding errors otherwise.

   for my $failure_response (@random_failure_responses) {
      print "failure response = $failure_response\n" if $debug;
      $values{"${prefix}$failure_response"} = int($counter_value / $failure_responses_count);
      $running_count -= $values{"${prefix}$failure_response"}; # decrement by average count
   }
   
   $values{"${prefix}$random_failure_responses[0]"} +=$running_count; # add any remaining count to the first failure_response. This ensures that SUM of all count values is correct.

   return %values;
}

exit 0;

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

=item * /eniq/home/dcuser/counters/ims/CSCF.counters

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

