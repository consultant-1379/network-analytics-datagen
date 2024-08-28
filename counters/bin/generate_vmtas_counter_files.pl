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
my $time      mvim counters/Features/All/create_ = '';
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
   mtas_20 => '18A',
   mtas_21 => '18A',
   mtas_22 => '18A',
#   mtas_23 => '18A',
#   mtas_24 => '18A',
#   mtas_25 => '18A',
#   mtas_26 => '18A',
#   mtas_27 => '18A',
   mtas_28 => '18A',
   mtas_29 => '18A',
);


my %counters_for;
my %formulas_for;

my $data_dir     = "/eniq/data/pmdata/$oss_id/MTAS_CBA/dir1";
my $counters_dir = '/eniq/home/dcuser/counters/nodes/vmtas';

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );
#print "Constants=[$constants]\n";
eval "$constants" if $constants;                # bring values of constants into local namespace

if ($debug) {
#   print "Constants : \n$constants\n";
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

create_pmdata_dirs($data_dir);

my %end_time_for = get_rop_times_5($time);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

# Some constants for MTAS
my $elementType       = 'MTAS';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V10.0';
my $measObjLdn        = 'DEFAULT';

my %sip_code_slogan_for  = get_sip_codes();
my @successful_responses = qw(180 181 182 183 199 200 202 204);
my @failure_responses    = qw(400 401 403 404 407 484 486 500 503 600); # 400, 401, 500, 503 are considered to be errors
my @ok_responses         = ('SIP,487', 'SIP,480', 182, 'Q.850,16', 'Q.850,102', 200, 202, 204);

my @cscfs = ('180.10.200.1', '181.10.202.2', '183.10.204.3', '184.10.199.4', '100.200.180.5');

# These counters are per CSCF
my @counters_per_cscf = qw(
MtasMmtTermOrigSessNOkE
MtasMmtTermOrigSessNOkI
MtasMmtOrigSessEarlyCancel
MtasMmtOrigUnregSessEarlyCancel
MtasMmtTermTermSessNOkE
MtasMmtTermTermSessNOkI
MtasMmtTermSessEarlyCancel
MtasMmtTermUnregSessEarlyCancel
MtasMmtInitOrigSessNOkI
MtasMmtInitOrigUnregSessNOkI
);

my $counters_per_cscf = join '|', @counters_per_cscf; # create a regex for later match

print "$counters_per_cscf\n" if $debug;

my @OSProcessingUnits = get_OSProcessingUnit();

for my $day_index ( $day_start .. $day_end ) {
   my $day   = add_leading_zero($day_index);
   my $month = add_leading_zero($month_start);

   print "$year_start-$month-$day\n" if $verbose;

   my $date = "$year_start$month$day";

   for my $start_time ( sort keys %end_time_for ) {
      print "   time = $start_time\n" if $verbose;

      my $end_time = $end_time_for{$start_time};

      for my $mtas_id (keys %node_version_for) {
         print "      mtas_id = $mtas_id\n" if $verbose;

         my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
         my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
         ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
         my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$timezone";

         my $dnPrefix  = "SubNetwork=ONRM_RootMo,MeContext=$mtas_id";
         my $localDn   = "$mtas_id";
         my $userLabel = "$mtas_id";

         my $mtas_file = "$data_dir/A$date.$start_time$timezone-$end_time${timezone}_${dnPrefix}_statsfile.xml";
#         my $mtas_file = "$data_dir/A$date.$start_time$timezone-$date.$end_time${timezone}_${dnPrefix}_statsfile.xml";

         open my $MTAS_FH, '>', "$mtas_file" or croak "Cannot open file $mtas_file, $!";
         print {$MTAS_FH} format_header_extended( $startdate, 'ManagedElement=1', $userLabel, $node_version_for{$mtas_id}, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $localDn), "\n";

         for my $mo_type ( sort keys %formulas_for ) {

            print "      mo_type = $mo_type\n" if $verbose;

            # MtasMmt success counters are indexed by cause code number, so need individual MOIDs for each cause code
            #
            # Success counters are:
            # MtasMmtOrigNetworkSuccessSessionEstablish
            # MtasMmtTermNetworkSuccessSessionEstablish
            #
            # MtasMmt failure counters are indexed by cause code number, so need individual MOIDs for each cause code
            # In addition, the sum of all failures is stored indexed by CSCF node instance, represented by its IP address
            #
            # Failure counters indexed by CSCF are:
            # MtasMmtOrigFailedAttempt
            # MtasMmtTermFailedAttempt
            #
            #
            # Failure counters indexed by cause code are:
            # MtasMmtOrigFailedAttemptCause
            # MtasMmtTermFailedAttemptCause
            #
            if ($mo_type eq 'MtasMmt') {
               print "      measObjLdn = $measObjLdn\n" if $verbose;
               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               print "      @counters_list\n" if $debug;

               my %formula_values = get_values_for($formulas_for{$mo_type});
#               print "      values $_ = $formula_values{$_}\n" for sort keys %formula_values;# if $debug;

               for my $counter (@counters_list) {
                  my $counter_value = $formula_values{$counter};
                  print "      $counter = $counter_value\n" if $debug;

                  if ($counter =~ m/Establish$/) {

                     # Distribute counter value among response codes 
                     my %values;
                     $values{180} = int($counter_value * 0.05);
                     $values{181} = int($counter_value * 0.015);
                     $values{182} = int($counter_value * 0.025);
                     $values{183} = int($counter_value * 0.005);
                     $values{199} = int($counter_value * 0.015);
                     $values{200} = int($counter_value * 0.8);
                     $values{202} = int($counter_value * 0.015);
                     $values{204} = $counter_value - ($values{180} + $values{181} + $values{182} + $values{183} + $values{199} + $values{200} + $values{202}) ;

                     for my $response (@successful_responses) {
                        print "         response = $response, value = $values{$response}\n" if $verbose;
                        print_measurement_info_with_value( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter, $response, $values{$response} );
                     }

                  } elsif ($counter =~ m/Attempt$/) {
                     print "  2    $counter        = $counter_value\n" if $debug;

                     # Distribute counter value among CSCFs
                     my %values_per_cscf;
                     $values_per_cscf{ $cscfs[0] } = int($counter_value * 0.25);
                     $values_per_cscf{ $cscfs[1] } = int($counter_value * 0.25);
                     $values_per_cscf{ $cscfs[2] } = int($counter_value * 0.20);
                     $values_per_cscf{ $cscfs[3] } = int($counter_value * 0.15);
                     $values_per_cscf{ $cscfs[4] } = $counter_value - ($values_per_cscf{ $cscfs[0] } + $values_per_cscf{ $cscfs[1] } + $values_per_cscf{ $cscfs[2] } + $values_per_cscf{ $cscfs[3] });

                     for my $cscf (@cscfs) {
                        print "         cscf = $cscf, value = $values_per_cscf{$cscf}\n" if $verbose;
                        print_measurement_info_with_value( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter, $cscf, $values_per_cscf{$cscf} );
                     }

                     print "  3    $counter = $counter_value\n" if $debug;
                     # Distribute counter value among response codes 
                     my %values;
                     $values{400} = int(rand($counter_value * 0.005)); # these count as errors
                     $values{401} = int(rand($counter_value * 0.005)); # these count as errors
                     $values{403} = int(rand($counter_value * 0.2));
                     $values{404} = int(rand($counter_value * 0.1));
                     $values{407} = int(rand($counter_value * 0.2));
                     $values{484} = int(rand($counter_value * 0.25));
                     $values{486} = int(rand($counter_value * 0.15));
                     $values{500} = int(rand($counter_value * 0.005)); # these count as errors
                     $values{503} = int(rand($counter_value * 0.005)); # these count as errors
                     $values{600} = $counter_value - ($values{400} + $values{401} + $values{403} + $values{404} + $values{407} + $values{484} + $values{486} + $values{500} + $values{503});

                     for my $response (@failure_responses) {
                        print "         response = $response, value = $values{$response}\n" if $verbose;
                        print_measurement_info_with_value( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, "${counter}Cause", "$response, $sip_code_slogan_for{$response}", $values{$response} );
                     }

                  } elsif ($counter =~ m/Ok$/) {

                     # Distribute counter value among response codes 
                     my %values;
                     $values{'SIP,487'}   = int($counter_value * 0.05);
                     $values{'SIP,480'}   = int($counter_value * 0.015);
                     $values{182}         = int($counter_value * 0.025);
                     $values{'Q.850,16'}  = int($counter_value * 0.005);
                     $values{'Q.850,102'} = int($counter_value * 0.015);
                     $values{200}         = int($counter_value * 0.8);
                     $values{202}         = int($counter_value * 0.015);
                     $values{204}         = $counter_value - ($values{'SIP,487'} + $values{'SIP,480'} + $values{182} + $values{'Q.850,16'} + $values{'Q.850,102'} + $values{200} + $values{202}) ;

                     for my $response (@ok_responses) {
                        print "         response = $response, value = $values{$response}\n" if $verbose;
                        print_measurement_info_with_value( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter, $response, $values{$response} );
                     }

                  } elsif ($counter =~ m/$counters_per_cscf/) {

                     # Distribute counter value among CSCFs
                     my %values_per_cscf;
                     $values_per_cscf{ $cscfs[0] } = int($counter_value * 0.25);
                     $values_per_cscf{ $cscfs[1] } = int($counter_value * 0.25);
                     $values_per_cscf{ $cscfs[2] } = int($counter_value * 0.20);
                     $values_per_cscf{ $cscfs[3] } = int($counter_value * 0.15);
                     $values_per_cscf{ $cscfs[4] } = $counter_value - ($values_per_cscf{ $cscfs[0] } + $values_per_cscf{ $cscfs[1] } + $values_per_cscf{ $cscfs[2] } + $values_per_cscf{ $cscfs[3] });

                     for my $cscf (@cscfs) {
                        print "         cscf = $cscf, value = $values_per_cscf{$cscf}\n" if $verbose;
                        print_measurement_info_with_value( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, $counter, $cscf, $values_per_cscf{$cscf} );
                     }
                  }

               }

            } elsif ($mo_type eq 'OSProcessingUnit') {
               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               print "      @counters_list\n" if $debug;

               print_measurement_info_start_with_measInfoId( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, @counters_list );
               for my $measObjLdn (@OSProcessingUnits) {
                  print "         OSProcessingUnit = $measObjLdn\n" if $verbose;
                  print_measurement_values( $MTAS_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
               }
               print_measurement_info_end($MTAS_FH);

            } elsif ($mo_type eq 'OSProcessingLogicalUnit') {
               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               print "      @counters_list\n" if $debug;

               print_measurement_info_start_with_measInfoId( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, @counters_list );
               for my $OSProcessingUnit (@OSProcessingUnits) {
                  for my $OSProcessingLogicalUnit (0 .. 21) {
                     $measObjLdn = "$OSProcessingUnit,OSProcessingSocketUnit=0,OSProcessingLogicalUnit=$OSProcessingLogicalUnit";
                     print "         measObjLdn = $measObjLdn\n" if $verbose;
                     print_measurement_values( $MTAS_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
                  }
               }
               print_measurement_info_end($MTAS_FH);

            } else {
               $measObjLdn = 'DEFAULT';                          
               print "      measObjLdn = $measObjLdn\n" if $verbose;
               my @counters_list = sort split /:/mx, $counters_for{$mo_type};
               print "      @counters_list\n" if $debug;
               print_measurement_info_start_with_measInfoId( $MTAS_FH, $rop_length_in_seconds, $stopdate, $mo_type, @counters_list );
               print_measurement_values( $MTAS_FH, $measObjLdn, \@counters_list, $formulas_for{$mo_type} );
               print_measurement_info_end($MTAS_FH);
            }


         }

         print {$MTAS_FH} format_footer($stopdate), "\n";
         close $MTAS_FH or croak "Cannot close file $mtas_file, $!";
      }
   }
}



sub get_sip_codes {

   return (
      100 => "Trying",
      180 => "Ringing",
      181 => "Call is Being Forwarded",
      182 => "Queued",
      183 => "Session in Progress",
      199 => "Early Dialog Terminated",
      200 => "OK",
      202 => "Accepted",
      204 => "No Notification",
      300 => "Multiple Choices",
      301 => "Moved Permanently",
      302 => "Moved Temporarily",
      305 => "Use Proxy",
      380 => "Alternative Service",
      400 => "Bad Request",
      401 => "Unauthorized",
      402 => "Payment Required",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed",
      406 => "Not Acceptable",
      407 => "Proxy Authentication Required",
      408 => "Request Timeout",
      409 => "Conflict",
      410 => "Gone",
      411 => "Length Required",
      412 => "Conditional Request Failed",
      413 => "Request Entity Too Large",
      414 => "Request-URI Too Long",
      415 => "Unsupported Media Type",
      416 => "Unsupported URI Scheme",
      417 => "Unknown Resource-Priority",
      420 => "Bad Extension",
      421 => "Extension Required",
      422 => "Session Interval Too Small",
      423 => "Interval Too Brief",
      424 => "Bad Location Information",
      428 => "Use Identity Header",
      429 => "Provide Referrer Identity",
      430 => "Flow Failed",
      433 => "Anonymity Disallowed",
      436 => "Bad Identity-Info",
      437 => "Unsupported Certificate",
      438 => "Invalid Identity Header",
      439 => "First Hop Lacks Outbound Support",
      470 => "Consent Needed",
      480 => "Temporarily Unavailable",
      481 => "Call/Transaction Does Not Exist",
      482 => "Loop Detected.",
      483 => "Too Many Hops",
      484 => "Address Incomplete",
      485 => "Ambiguous",
      486 => "Busy Here",
      487 => "Request Terminated",
      488 => "Not Acceptable Here",
      489 => "Bad Event",
      491 => "Request Pending",
      493 => "Undecipherable",
      494 => "Security Agreement Required",
      500 => "Server Internal Error",
      501 => "Not Implemented",
      502 => "Bad Gateway",
      503 => "Service Unavailable",
      504 => "Server Time-out",
      505 => "Version Not Supported",
      513 => "Message Too Large",
      580 => "Precondition Failure",
      600 => "Busy Everywhere",
      603 => "Decline",
      604 => "Does Not Exist Anywhere",
      606 => "Not Acceptable",

   );
}

sub get_OSProcessingUnit {
return (
'OSProcessingUnit=PL-10',
'OSProcessingUnit=PL-11',
'OSProcessingUnit=PL-12',
'OSProcessingUnit=PL-3',
'OSProcessingUnit=PL-4',
'OSProcessingUnit=PL-5',
'OSProcessingUnit=PL-6',
'OSProcessingUnit=PL-7',
'OSProcessingUnit=PL-8',
'OSProcessingUnit=PL-9',
'OSProcessingUnit=SC-1',
'OSProcessingUnit=SC-2',
);
}



__END__

sub get_SIP_causes {
   return (
'Q.850,1',
'Q.850,102',
'Q.850,111',
'Q.850,127',
'Q.850,16',
'Q.850,17',
'Q.850,18',
'Q.850,19',
'Q.850,20',
'Q.850,21',
'Q.850,22',
'Q.850,27',
'Q.850,28',
'Q.850,29',
'Q.850,3',
'Q.850,31',
'Q.850,34',
'Q.850,38',
'Q.850,41',
'Q.850,42',
'Q.850,44',
'Q.850,47',
'Q.850,55',
'Q.850,57',
'Q.850,65',
'Q.850,69',
'Q.850,79',
'Q.850,8',
'Q.850,88',
'Q.850,95',
'Q.850,97',
'Q.850,99',
'SIP,"Call Rejected By User"',
'SIP,"Conference call is empty"',
'SIP,"Dedicated Bearer Lost"',
'SIP,"Deregistering"',
'SIP,"Hold/resume timeout"',
'SIP,"INTERNAL ERROR"',
'SIP,"Invalid SDP"',
'SIP,"Joined N-way Call"',
'SIP,"MBR/GBR not met"',
'SIP,"Missing SDP Answer"',
'SIP,"Moved to non-LTE access network"',
'SIP,"No ACK received"',
'SIP,"No Answer"',
'SIP,"Precondition Timeout"',
'SIP,"Received reject SDP"',
'SIP,"Remote end CANCELed a completed transaction"',
'SIP,"Remote end rejected INVITE request  with response 480"',
'SIP,"Remote end rejected INVITE request  with response 487"',
'SIP,"Remote end rejected INVITE request  with response 500"',
'SIP,"Remote end rejected INVITE request  with response 606"',
'SIP,"Remote end rejected PRACK"',
'SIP,"Remote end rejected UPDATE request  with response 403"',
'SIP,"RTCP Timeout"',
'SIP,"RTP Timeout"',
'SIP,"Session Expired"',
'SIP,"User Triggered"',
'SIP,16',
'SIP,200',
'SIP,404',
'SIP,408',
'SIP,480',
'SIP,487',
'SIP,500',
'SIP,503',
'SIP,504',
   );
}


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



