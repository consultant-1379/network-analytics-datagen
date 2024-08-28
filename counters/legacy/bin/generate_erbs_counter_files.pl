#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::ReportsXSD;
use ENIQ::Reports;
use Carp;

#use YAML::Tiny;

my $usage = <<"USAGE";
 This script creates and populates the counter ROP files with sample data.

 Usage:
        $0 [options]

    -n <NEs>, --nes=<NEs>
                number of NEs (ERBSs)   [default is 250]
    -c <eutrancells>, --cells=<cells>
                number of EUtranCells per ERBS [default is 3]
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
        $0 -s 2007-04-01 -e 2007-04-20 -n 20 -c 6 

 will create the ROP files for all counters in the input files, for the date range and number of NEs/EUtranCells given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.

USAGE

my ( $day_today, $month_today, $year_today ) = get_todays_date();

my $debug      	= '';
my $help       	= '';
my $verbose    	= '';                                       # default is off
my $nes        	= 300;                                      # default is 300
my $eutrancells   = 3;                                        # default is 3
my $time       	= '';
my $rop_length    = 15;                                       # default is 15 minutes
my $start_date 	= "$year_today-$month_today-$day_today";    # default is today
my $end_date   	= $start_date;                              

GetOptions(
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
   'cells=s'      => \$eutrancells,
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
   print 'ROP time        = ', ($time) ? $time : 'not specified', "\n";
   print "ROP length      = $rop_length\n";
   print "Number of ERBSs                    = $nes\n";
   print "Number of EUtranCells              = $eutrancells\n";
}

check_for_valid_date_time( $day_start, $day_end, $month_start, $time );

die "\nYear must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n"  if $year_start  ne $year_end;
die "\nMonth must be the same for start date ($start_date) and end date ($end_date)\n\n$usage\n\n" if $month_start ne $month_end;
die "\nNumber of ERBSs ($nes) must be > 0\n\n$usage\n\n"                                            if $nes le '0';
die "\nNumber of EUtranCells ($eutrancells) must be > 0\n\n$usage\n\n" if $eutrancells le '0';

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my @erbs_generations    = qw(G1 G2);
my @erbs_range          = ( 1 .. $nes );
my @eutrancell_range	   = ( 1 .. $eutrancells );
my @cell_types          = ('FDD', 'TDD', 'FDD/TDD');

my %relation_types      = (
   Cdma20001xRttCellRelation => 3,
   EUtranCellRelation        => 10,
   GeranCellRelation         => 3,
   UtranCellRelation         => 6
);


my %counters_for;
my %formulas_for;

my $data_dir     = '/eniq/data/pmdata/eniq_oss_1/lterbs/dir1/'; 
my $data_dir_g2  = '/eniq/data/pmdata/eniq_oss_1/RadioNode/LRAT/dir1/'; 

my $counters_dir = '/eniq/home/dcuser/counters/erbs';

my $constants = read_counters( $counters_dir, \%counters_for, \%formulas_for );

if ($debug) {
#   print "Counters for\n",   YAML::Tiny::Dump( \%counters_for );
#   print "\nFormulas for\n", YAML::Tiny::Dump( \%formulas_for );
}

create_pmdata_dirs($data_dir);
create_pmdata_dirs($data_dir_g2);


my %end_time_for = get_rop_times($time);
my $rop_length_in_seconds = $rop_length * 60; # file details need ROP length in seconds

my %moid_for = (
   CapacityConnectedUsers    => 'ManagedElement=1,SystemFunctions=1,Licensing=1,CapacityLicenses=1,CapacityConnectedUsers=1',
   Cdma20001xRttCellRelation => 'ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1,Cdma20001xRttBandRelation=1,Cdma20001xRttFreqRelation=1,Cdma20001xRttCellRelation=1',
   DlBasebandCapacity        => 'ManagedElement=1,SystemFunctions=1,Licensing=1,CapacityLicenses=1',
   DlPrbCapacity             => 'ManagedElement=1,SystemFunctions=1,Licensing=1,CapacityLicenses=1,DlPrbCapacity=1',
   ENodeBFunction            => 'ManagedElement=1,ENodeBFunction=1',
   EthernetLink              => 'ManagedElement=1,IpOam=1,IpSystem=1,Ip=1,EthernetLink=1',
   EUtranCellFDD             => 'ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1',
   EUtranCellRelation        => 'ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1,EUtranFreqRelation=1,EUtranCellRelation=1',
   FastEhernet               => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1,Cbu=1,GeneralProcessorUnit=1,FastEthernet=1',
   GeranCellRelation         => 'ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1,GeranFreqGroupRelation=1,GeranCellRelation=1',
   GigaBitEthernet           => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1,ExchangeTerminalIp=1,GigaBitEthernet=1',
   IkePeer                   => 'ManagedElement=1,IpSystem=1,IpSec=1,IkePeer=1',
   InternalEthernetPort      => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1,ExchangeTerminalIp=1,InternalEthernetPort=1',
   Ip                        => 'ManagedElement=1,IpOam=1,IpSystem=1,Ip=1',
   IpAccessHostEt            => 'ManagedElement=1,IpSystem=1,IpAccessHostEt=1',
   IpAccessHostGpb           => 'ManagedElement=1,IpSystem=1,IpAccessHostGpb=1',
   IpAccessHostSpb           => 'ManagedElement=1,IpSystem=1, IpAccessHostSpb=1',
   IpHostLink                => 'ManagedElement=1,IpOam=1,Ip=1,IpHostLink=1',
   IpInterface               => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1,ExchangeTerminalIp=1,GigaBitEthernet=1,IpInterface=1',
   IpMux                     => 'ManagedElement=1,IpSystem=1,IpMux=1',
   IpSecTunnel               => 'ManagedElement=1,IpSystem=1,IpSec=1,IpSecTunnel=1',
   Ipv6Interface             => 'ManagedElement=1,IpSystem=1,Ipv6Interface=1',
   MediumAccessUnit          => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1,Cbu=1,GeneralProcessorUnit=1,MediumAccessUnit=1',
   PlugInUnit                => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1',
   PmUeMeasControl           => 'ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1,UeMeasControl=1,PmUeMeasControl=1',
   ProcessorLoad             => 'ManagedElement=1,Equipment=1,Subrack=1,Slot=1,PlugInUnit=1,GeneralProcessorUnit=1,ProcessorLoad=1',
   Sctp                      => 'ManagedElement=1,TransportNetwork=1,Sctp=1',
   SectorCarrier             => 'ManagedElement=1,ENodeBFunction=1,SectorCarrier=1',
   SecurityHandling          => 'ManagedElement=1,ENodeBFunction=1,SecurityHandling=1',
   Synchronization           => 'ManagedElement=1,TransportNetwork=1,Synchronization=1',
   UlBasebandCapacity        => 'ManagedElement=1,SystemFunctions=1,Licensing=1,CapacityLicenses=1',
   UlPrbCapacity             => 'ManagedElement=1,SystemFunctions=1,Licensing=1,CapacityLicenses=1,UlPrbCapacity=1',
   UtranCellRelation         => 'ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1,UtranFreqRelation=1,UtranCellRelation=1',
   VpnInterface              => 'ManagedElement=1,IpSystem=1,VpnInterface=Top N Based On Initial E-RAB Establishment Success Rate Per QCI1',
);

my $cell_type;

print "NEs = $nes\n" if $verbose;

my $elementType       = 'ERBS';
my $swVersion         = '16A';
my $vendorName        = 'Ericsson';
my $fileFormatVersion = '32.435 V10.0';
my %mo_accumulated_ref;


for my $day_index ( $day_start .. $day_end ) {
   my $day   = add_leading_zero($day_index);
   my $month = add_leading_zero($month_start);

   print "$year_start-$month-$day\n" if $verbose;

   my $date = "$year_start$month$day";    # don't insert / or -, this format is used in ROP file

   for my $start_time ( sort keys %end_time_for ) {
      print "   time = $start_time\n" if $verbose;

      my $end_time = $end_time_for{$start_time};

      for my $erbs_generation (@erbs_generations) {
         my $erbs_prefix = 'erbs';
         $erbs_prefix .= 'G2' if $erbs_generation eq 'G2';

         for my $erbs_index (@erbs_range) {
            print "      erbs_index = $erbs_index\n" if $verbose;
            my $erbs_id          = sprintf("${erbs_prefix}_%04d", $erbs_index);
            my $erbs_cell_prefix = sprintf("%04d", $erbs_index);
            print "      erbs_id = $erbs_id\n" if $verbose;

            $cell_type = 'FDD'     if $erbs_index <= $nes/3;                            # FDD nodes range from 001-100            
            $cell_type = 'TDD'     if $erbs_index > $nes/3 and $erbs_index <= 2*$nes/3; # TDD nodes range from 101-200          
            $cell_type = 'FDD/TDD' if $erbs_index > 2*$nes/3;                           # FDD/TDD nodes range from 201-300

            print "      cell_type = $cell_type\n" if $verbose;

            my $startdate = "$date${start_time}00$timezone";
            my $stopdate  = "$date${end_time}00$timezone";

            my $erbs_fdn  = "$root_mo,MeContext=$erbs_id";
            my $dnPrefix  = $erbs_fdn;
            my $localDn   = "MeContext=$erbs_id";
            my $meLocalDn = $localDn;
            my $userLabel = $erbs_id;

            if ($erbs_generation eq 'G1') {
               my $startdate = "$date${start_time}00$timezone";
               my $stopdate  = "$date${end_time}00$timezone";
               my $erbs_file = "$data_dir/A$date.$start_time$timezone-$end_time${timezone}_${erbs_fdn}.xml";
               open my $ERBS_FH, '>', "$erbs_file" or croak "Cannot open file $erbs_file, $!";

               print {$ERBS_FH} ENIQ::Reports::format_header( $erbs_fdn, $startdate ), "\n";

               for my $mo_type ( sort keys %formulas_for ) {
                  my $measObjLdn = $mo_type;
                  next if ($mo_type =~ m/Relation/);

                  my @counters_list = sort split /:/mx, $counters_for{$mo_type};
                  ENIQ::Reports::print_measurement_info_start( $ERBS_FH, $rop_length_in_seconds, $stopdate, @counters_list );

                  ## Create Eutrancells
                  for my $eutrancell_index (@eutrancell_range) {
                     my $eutrancell_id = $eutrancell_index;
                     if ($cell_type eq 'FDD') {
                        my $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellFDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::Reports::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );                       
                     }
                     elsif ($cell_type eq 'TDD') {
                        my $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellTDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::Reports::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );
                     } 
                     elsif ($cell_type eq 'FDD/TDD') {
                        my $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellFDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::Reports::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );

                        $eutrancell_id += $eutrancells; # TDD cells are indexed from 4 - 6 
                        $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellTDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::Reports::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );
                     } 
                     else {
                        die "Unknown cell type: $cell_type";
                     }
                  }    
                  ENIQ::Reports::print_measurement_info_end($ERBS_FH);

                  if ($mo_type =~ m/EUtranCell(FDD|TDD)/) {
                     my $cell_type = $1;
                     for my $eutrancell_index (@eutrancell_range) {
                        print_relations($ERBS_FH, $stopdate, $cell_type, "$erbs_cell_prefix-$eutrancell_index");
                     }
                  }
               }

               print {$ERBS_FH} ENIQ::Reports::format_footer($stopdate), "\n" if $erbs_generation eq 'G1';

               close $ERBS_FH or croak "Cannot close file $erbs_file, $!";

            } else {
               
               my ($hours, $minutes) = $start_time =~ m/(\d\d)(\d\d)/;
               my $startdate = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
               ($hours, $minutes) = $end_time =~ m/(\d\d)(\d\d)/;
               my $stopdate  = "$year_start-$month-${day}T$hours:$minutes:00$timezone";
               
               my $erbs_file = "$data_dir_g2/A$date.$start_time$timezone-$end_time${timezone}_${erbs_fdn}_statsfile.xml";
               open my $ERBS_FH, '>', "$erbs_file" or croak "Cannot open file $erbs_file, $!";

               print {$ERBS_FH} ENIQ::ReportsXSD::format_header_extended( $startdate, $localDn, $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $meLocalDn), "\n";

               for my $mo_type ( sort keys %formulas_for ) {
                  my $measObjLdn = $mo_type;

                  my @counters_list = sort split /:/mx, $counters_for{$mo_type};
                  ENIQ::ReportsXSD::print_measurement_info_start_with_measInfoId( $ERBS_FH, $rop_length_in_seconds, $stopdate, $measObjLdn, @counters_list );

                  ## Create Eutrancells
                  for my $eutrancell_index (@eutrancell_range) {
                     my $eutrancell_id = $eutrancell_index;
                     if ($cell_type eq 'FDD') {
                        my $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellFDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::ReportsXSD::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );
                     }
                     elsif ($cell_type eq 'TDD') {
                        my $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellTDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::ReportsXSD::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );
                     } 
                     elsif ($cell_type eq 'FDD/TDD') {
                        my $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellFDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::ReportsXSD::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );

                        $eutrancell_id += $eutrancells; # TDD cells are indexed from 4 - 6 
                        $moid = $moid_for{$mo_type};
                        $moid =~ s/EUtranCellFDD=1/EUtranCellTDD=$erbs_cell_prefix-$eutrancell_id/;
                        ENIQ::ReportsXSD::print_measurement_values( $ERBS_FH, $moid, \@counters_list, $formulas_for{$mo_type} );
                     } 
                     else {
                        die "Unknown cell type: $cell_type";
                     }
                  }    
                  ENIQ::ReportsXSD::print_measurement_info_end($ERBS_FH);          
               }

               print {$ERBS_FH} ENIQ::ReportsXSD::format_footer($stopdate), "\n";

               close $ERBS_FH or croak "Cannot close file $erbs_file, $!";
            }
         }
      }
   }
}

sub print_relations {
   my ($ERBS_FH, $stopdate, $cell_type, $cell_prefix, $counters_list_ref, $formulas) = @_;

   for my $mo_type (keys %relation_types) {
      my @counters_list = sort split /:/mx, $counters_for{$mo_type};

      ENIQ::Reports::print_measurement_info_start( $ERBS_FH, $rop_length_in_seconds, $stopdate, @counters_list );
      
      my $relation_moid = $moid_for{$mo_type};
      for my $relation_index (1 .. $relation_types{$mo_type}) {
         my $relation = $relation_moid;
         $relation =~ s/EUtranCellFDD=1/EUtranCell${cell_type}=$cell_prefix/;
         $relation =~ s/1$/$cell_prefix-$relation_index/;
         ENIQ::Reports::print_measurement_values( $ERBS_FH, $relation, \@counters_list, $formulas_for{$mo_type} );
      }

      ENIQ::Reports::print_measurement_info_end($ERBS_FH);     
   }
}



__END__

$Author: eeikcoy $

$Date: 2007-09-07 09:33:25 +0100 (Fri, 07 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_erbs_counter_files.pl $

$Id: generate_erbs_counter_files.pl 51 2007-09-07 08:33:25Z eeikcoy $


=head1 NAME

generate_erbs_counter_files - creates the ENIQ counter directories and files for ERBS nodes.

=head1 VERSION

This documentation refers to generate_erbs_counter_files.pl version 1.0. 

=head1 USAGE

Run using the command:

=over 

=item    generate_erbs_counter_files.pl [options] 

=back

 Example:
        generate_erbs_counter_files.pl 

 will create the ROP files for all counters for today.

 Example:
        generate_erbs_counter_files.pl -t 1000

 will create the ROP files for all counters for time 1000.

 Example:
        generate_erbs_counter_files.pl -s 2007-04-01 -e 2007-04-20 -n 20 -c 750 

 will create the ROP files for all counters, for the date range, ERBSs and Cells given.

 If a ROP time is specified, there will only be one file produced for the given time, 
 otherwise 96 ROP files for the whole day will be generated.

 Note that start and end dates must be in the same calendar month.

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

    -n <NEs>, --nes=<NEs>
                number of NEs (ERBSs)   [default is 10]
    -c <cells>, --cells=<cells>
                number of EUtranCells per ERBS [default is 100]
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

This script generates counter directories and files for the ERBS nodes.

This script creates and populates the counter ROP files with sample data.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/erbs

=item * /eniq/data/pmdata/eniq_oss_1/lterbs/dir1

=back

=head2 Counter Files

The counter topology files are stored in the dir1 directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/erbs/dir1/A20070906.1300+0100-1315+0100_SubNetwork=ONRM_RootMo,SubNetwork=erbs07,MeContext=erbs07_statsfile.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

The counter definition files have the extension .counters and must be in the directory:

=over

=item * /eniq/home/dcuser/counters/erbs

=back

The current set of supported counters are defined in:

=over

=item * /eniq/home/dcuser/counters/erbs/EUtranCell.counters

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


__END__


