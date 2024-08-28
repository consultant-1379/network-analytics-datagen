package ENIQ::ReportsXSD;

use 5.008004;
use strict;
use warnings;
use Carp;

#use YAML::Tiny;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use ENIQ::Reports ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
    'all' => [
        qw(

          )
    ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
  add_leading_zero
  check_for_valid_date
  check_for_valid_date_time
  check_for_valid_time
  create_pmdata_dirs
  create_site_topology_file
  format_footer
  format_header
  format_header_extended  
  get_rop_times
  get_rop_times_5
  get_todays_date
  get_config_data
  get_configuration_data
  get_date_ymd
  get_ne_list
  get_values_for
  print_measurement_values
  print_accumulated_measurement_values
  print_measurement_info_end
  print_measurement_info_start
  print_measurement_info_start_with_measInfoId
  print_measurement_info_with_value
  print_measurement_info_with_values
  read_counters
  topology_header
  topology_footer
);

our $VERSION = '1.0';

use constant MAX_COUNTER_VALUE => 2**32;    # long integer is 32 bits

my %values_for;

# Preloaded methods go here.

sub get_todays_date {
    my ( $day_today, $month_today, $year_today ) = (localtime)[ 3, 4, 5 ];
    $year_today += 1900;
    $month_today++;
    return $day_today, $month_today, $year_today;
}

sub check_for_valid_date_time {
    my ( $day_start, $day_end, $month, $time ) = @_;

    check_for_valid_date( $day_start, $day_end, $month );
    check_for_valid_time($time) if $time;
    return;
}

sub check_for_valid_date {
    my ( $day_start, $day_end, $month ) = @_;

    # some sanity checks in case invalid data entered above
    my $last_day_in_month =
        ( $month == 2 ) ? 29
      : ( $month == 9 or $month == 4 or $month == 6 or $month == 11 ) ? 30
      :                                                                 31;

    croak "Invalid month value=$month\n"                                            unless $month >= 1            and $month <= 12;
    croak "Invalid day_start value=$day_start\n"                                    unless $day_start >= 1        and $day_start <= $last_day_in_month;
    croak "Invalid day_end value=$day_end for day_start=$day_start, month=$month\n" unless $day_end >= $day_start and $day_end <= $last_day_in_month;
    return;
}

sub check_for_valid_time {
    my ($time) = shift;

    croak "Invalid time=$time, must have 4 digits\n" unless length $time == 4;
    my $minutes = $time % 100;

    #    print "minutes=$minutes\n";
    croak "Invalid time=$time, must end with 00, 05, 10, 15, 20, 25, 30, 35, 40, 45, 50 or 55\n" unless $minutes % 5 == 0;
    my $hour = int $time / 100;

    #    print "hour=$hour\n";
    croak "Invalid time=$time, must be between 00 and 23 hours\n" unless $hour >= 0 and $hour <= 23;
    return;
}

sub create_pmdata_dirs {
    my @dirs = @_;
    for my $path (@dirs) {
        for my $dir ( split /\//xm, $path ) {
            if ( length $dir == 0 ) {
                chdir '/';
            }
            else {
                mkdir $dir;
                chdir $dir;
            }
        }
    }
    return;
}

sub get_rop_times {
    my ($time, $rop_length) = @_;

    my %end_time_for;

    my @hours = '00' .. '23';

    if ($rop_length and $rop_length == 5) {
       my %twelfth_hour_endtime_for = (
           '00' => '05',
           '05' => '10',
           '10' => '15',
           '15' => '20',
           '20' => '25',
           '25' => '30',
           '30' => '35',
           '35' => '40',
           '40' => '45',
           '45' => '50',
           '50' => '55',
           '55' => '00',           
       );

       my @twelfth_hours = sort keys %twelfth_hour_endtime_for;

       for my $hour (@hours) {
           my $hour_end = $hour;

           for my $twelfth_hour (@twelfth_hours) {
               $hour_end++ if $twelfth_hour eq '55';

               my $min_end  = $twelfth_hour_endtime_for{$twelfth_hour};
               my $end_time = "$hour_end$min_end";
               $end_time = '0000' if $end_time eq '2400';    # midnight is 0000 not 2400
               $twelfth_hour = add_leading_zero($twelfth_hour) ;
               my $start_time = "$hour$twelfth_hour";
               $end_time_for{$start_time} = $end_time;
           }
       }
    } else { # default to 15 minute ROP
       my %quarter_hour_endtime_for = (
           '00' => '15',
           '15' => '30',
           '30' => '45',
           '45' => '00',
       );

       my @quarter_hours = sort keys %quarter_hour_endtime_for;

       for my $hour (@hours) {
           my $hour_end = $hour;

           for my $quarter_hour (@quarter_hours) {
               $hour_end++ if $quarter_hour eq '45';

               my $min_end  = $quarter_hour_endtime_for{$quarter_hour};
               my $end_time = "$hour_end$min_end";
               $end_time = '0000' if $end_time eq '2400';    # midnight is 0000 not 2400
               my $start_time = "$hour$quarter_hour";
               $end_time_for{$start_time} = $end_time;
           }
       }
    }

    # if $time was given, then remove other ROPs except for this one
    if ($time) {
        for my $start_time ( keys %end_time_for ) {
            delete $end_time_for{$start_time} unless $start_time eq $time;    # remove all end-times except the given start time
        }
    }

    return %end_time_for;
}


sub get_rop_times_5 {
    my ($time) = shift;

    my %end_time_for;

    my @hours                    = '00' .. '23';
    my %twelfth_hour_endtime_for = (
        '00' => '05',
        '05' => '10',
        '10' => '15',
        '15' => '20',
        '20' => '25',
        '25' => '30',
        '30' => '35',
        '35' => '40',
        '40' => '45',
        '45' => '50',
        '50' => '55',
        '55' => '00',
    );

    my @twelfth_hours = sort keys %twelfth_hour_endtime_for;

    for my $hour (@hours) {
        my $hour_end = $hour;

        for my $twelfth_hour (@twelfth_hours) {
            $hour_end++ if $twelfth_hour eq '55';

            my $min_end  = $twelfth_hour_endtime_for{$twelfth_hour};
            my $end_time = "$hour_end$min_end";
            $end_time = '0000' if $end_time eq '2400';    # midnight is 0000 not 2400
            my $start_time = "$hour$twelfth_hour";
            $end_time_for{$start_time} = $end_time;
        }
    }

    # if $time was given, then remove other ROPs except for this one
    if ($time) {
        for my $start_time ( keys %end_time_for ) {
            delete $end_time_for{$start_time} unless $start_time eq $time;    # remove all end-times except the given start time
        }
    }

    return %end_time_for;
}


sub add_leading_zero {
    my ($padded) = shift;

    $padded = "0$padded" if length $padded == 1;                              # add leading 0 if necessary

    return $padded;
}

sub get_config_data {
    my %config;
    my $config_file = '/eniq/home/dcuser/counters/etc/counters.conf';    # default location of config file
    open my $CONF_FH, '<', "$config_file" or croak "Cannot open file $config_file, $!";

    while (<$CONF_FH>) {
        chomp;                                                                # no newline
        s/#.*//xm;                                                            # no comments
        s/^\s+//xm;                                                           # no leading white
        s/\s+$//xm;                                                           # no trailing white
        next unless length;                                                   # anything left?
        my ( $var, $value ) = split /\s*=\s*/xm, $_, 2;
        $config{$var} = $value;
    }

    close $CONF_FH or croak "Cannot close file $config_file, $!";

    # set default values if nothing in config file
    my $timezone = ( $config{TIMEZONE} )  ? $config{TIMEZONE}  : 'Z';
    my $oss_id   = ( $config{OSS_ID} )    ? $config{OSS_ID}    : 'eniq_oss_1';
    my $site     = ( $config{SITE_NAME} ) ? $config{SITE_NAME} : 'Athlone';
    my $root_mo  = ( $config{ROOT_MO} )   ? $config{ROOT_MO}   : 'SubNetwork=ONRM_RootMo';

    return ( $timezone, $oss_id, $site, $root_mo );
}

sub get_configuration_data {
    my $node_type    = shift;
    my %config;
    my $node_config_dir = "/eniq/home/dcuser/counters/etc/$node_type";

    opendir my $DIR, $node_config_dir or croak "Cannot open node configuration dir $node_config_dir: $!";
    while ( defined( my $file = readdir $DIR ) ) {
       next unless $file =~ m/\.conf$/i;    # Counters files must have extension .conf

       my ($node_id) = $file =~ m/([\w-]+)\.conf$/;

       my $config_file = "$node_config_dir/$node_id.conf";
       open my $CONF_FH, '<', "$config_file" or croak "Cannot open file $config_file, $!";

       while (<$CONF_FH>) {
          chomp;                                                                # no newline
          s/#.*//xm;                                                            # no comments
          s/^\s+//xm;                                                           # no leading white
          s/\s+$//xm;                                                           # no trailing white
          next unless length;                                                   # anything left?
          my ( $var, $value ) = split /\s*=\s*/xm, $_, 2;
          $config{$node_id}{$var} = $value;
       }

       close $CONF_FH or croak "Cannot close file $config_file, $!";

       # set default values if nothing in config file
       my $timezone = ( $config{$node_id}{TIMEZONE} )  ? $config{$node_id}{TIMEZONE}  : 'Z';
       my $oss_id   = ( $config{$node_id}{OSS_ID} )    ? $config{$node_id}{OSS_ID}    : 'eniq_oss_1';
       my $site     = ( $config{$node_id}{SITE_NAME} ) ? $config{$node_id}{SITE_NAME} : 'Athlone';
       my $root_mo  = ( $config{$node_id}{ROOT_MO} )   ? $config{$node_id}{ROOT_MO}   : 'SubNetwork=ONRM_RootMo';        

    }
    closedir $DIR or croak "Cannot closedir $node_config_dir: $!";

    return %config;
}


sub get_date_ymd {
    my $date = shift;

    my ( $year, $month, $day ) = split /[-\/]/xm, $date;
    $year  = "20$year" if length $year == 2;
    $day   = add_leading_zero($day);
    $month = add_leading_zero($month);

    return ( $year, $month, $day );
}

sub get_ne_list {
    my ( $ne_prefix, $num_nes ) = @_;

    my @nes;
    
    for my $id (1 .. $num_nes) {
       my $ne_name = sprintf("$ne_prefix%02d", $id);
       push @nes, $ne_name;
    }

    return @nes;
}

sub format_header {
    my ( $beginTime, $localDn, $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion ) = @_;
    return <<"HEADER";
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type=text/xsl href="MeasDataCollection.xsl"?>
<measCollecFile xmlns="http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec">
<fileHeader fileFormatVersion="$fileFormatVersion" vendorName="$vendorName" dnPrefix="$dnPrefix">
<fileSender localDn="$localDn" elementType="$elementType"/>
<measCollec beginTime="$beginTime"/>
</fileHeader>
<measData>
<managedElement localDn="$localDn" userLabel="$userLabel" swVersion="$swVersion"/>
HEADER
}

sub format_header_extended {
    my ( $beginTime, $localDn, $userLabel, $swVersion, $dnPrefix, $elementType, $vendorName, $fileFormatVersion, $meLocalDn ) = @_;
    return <<"HEADER";
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type=text/xsl href="MeasDataCollection.xsl"?>
<measCollecFile xmlns="http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec">
<fileHeader fileFormatVersion="$fileFormatVersion" vendorName="$vendorName" dnPrefix="$dnPrefix">
<fileSender localDn="$localDn" elementType="$elementType"/>
<measCollec beginTime="$beginTime"/>
</fileHeader>
<measData>
<managedElement localDn="$meLocalDn" userLabel="$userLabel" swVersion="$swVersion"/>
HEADER
}

sub format_footer {
    my ($endTime) = @_;
    return <<"FOOTER";
</measData>
<fileFooter>
<measCollec endTime="$endTime"/>
</fileFooter>
</measCollecFile>
FOOTER
}

sub format_header_dtd {
    my ( $beginTime, $fileFormatVersion, $subnetwork, $vendorName, $localDn, $userLabel ) = @_;
    return <<"HEADER";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="MeasDataCollection.xsl" ?>
<!DOCTYPE mdc SYSTEM "MeasDataCollection.dtd">
<mdc xmlns:HTML="http://www.w3.org/TR/REC-xml">
<mfh>
<ffv>$fileFormatVersion</ffv>
<sn>$subnetwork</sn>
<st></st>
<vn>$vendorName</vn>
<cbt>$beginTime</cbt>
</mfh>
<md>
<neid>
<neun>$userLabel</neun>
<nedn>$localDn</nedn>
</neid>
HEADER
}

sub format_footer_dtd {
    my ($endTime) = @_;
    return <<"FOOTER";
</md>
<mff>
<ts>$endTime</ts>
</mff>
</mdc>
FOOTER
}

sub topology_header {
    return <<'HEADER';
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE model PUBLIC "-//Ericsson NMS CIF CS//CS Filtered Export DTD//" "export.dtd">
<model>  
HEADER
}

sub topology_footer {
    return <<'FOOTER';
</model>
FOOTER
}

sub print_measurement_info_start {
    my ( $FH, $rop_length_in_seconds, $stopdate, @counters_list ) = @_;
    my $count = 1;

    print {$FH} "<measInfo measInfoId=\"1\">\n";
    print {$FH} "  <job jobId=\"1\"/>\n";
    print {$FH} "  <granPeriod duration=\"PT${rop_length_in_seconds}S\" endTime=\"$stopdate\"/>\n";
    print {$FH} "  <repPeriod duration=\"PT${rop_length_in_seconds}S\"/>\n";
    print {$FH} "  <measType p=\"" . $count++ . "\">$_</measType>\n" for @counters_list;
    return;
}

sub print_measurement_info_start_with_measInfoId {
    my ( $FH, $rop_length_in_seconds, $stopdate, $measInfoId, @counters_list ) = @_;
    my $count = 1;

    my @new_counters_list = @counters_list;
    s/_/./g for @new_counters_list;    # replace any underscores with dot, used in MTAS counters 
    
    print {$FH} "<measInfo measInfoId=\"$measInfoId\">\n";
    print {$FH} "  <job jobId=\"1\"/>\n";
    print {$FH} "  <granPeriod duration=\"PT${rop_length_in_seconds}S\" endTime=\"$stopdate\"/>\n";
    print {$FH} "  <repPeriod duration=\"PT${rop_length_in_seconds}S\"/>\n";
    print {$FH} "  <measType p=\"" . $count++ . "\">$_</measType>\n" for @new_counters_list;
    return;
}

sub print_measurement_info_end {
    my ($FH) = @_;
    print {$FH} "</measInfo>\n";
    return;
}


sub print_measurement_info_start_dtd {
    my ( $FH, $stopdate, $rop_seconds, @counters_list ) = @_;
    my $count = 1;

    print {$FH} "<mi>\n";
    print {$FH} "  <mts>$stopdate</mts>\n";
    print {$FH} "  <gp>$rop_seconds</gp>\n";
    print {$FH} "  <mt>$_</mt>\n" for @counters_list;
    return;
}

sub print_measurement_info_end_dtd {
    my ($FH) = @_;
    print {$FH} "</mi>\n";
    return;
}

sub print_measurement_info_with_value {
    my ( $FH, $rop_length_in_seconds, $stopdate, $measInfoId, $counter, $measObjLdn, $value ) = @_;
    my $count = 1;

    print {$FH} "<measInfo measInfoId=\"$measInfoId\">\n";
    print {$FH} "  <job jobId=\"1\"/>\n";
    print {$FH} "  <granPeriod duration=\"PT${rop_length_in_seconds}S\" endTime=\"$stopdate\"/>\n";
    print {$FH} "  <repPeriod duration=\"PT${rop_length_in_seconds}S\"/>\n";
    print {$FH} "  <measType p=\"1\">$counter</measType>\n";
    print {$FH} "  <measValue measObjLdn=\"$measObjLdn\">\n";
    print {$FH} "     <r p=\"1\">$value</r>\n";
    print {$FH} "  </measValue>\n";
    print {$FH} "</measInfo>\n";
    return;
}

sub print_measurement_info_with_values {
    my ( $FH, $rop_length_in_seconds, $stopdate, $measInfoId, $counter, $p, %value_for ) = @_;

    print {$FH} "<measInfo measInfoId=\"$measInfoId\">\n";
    print {$FH} "  <job jobId=\"1\"/>\n";
    print {$FH} "  <granPeriod duration=\"PT${rop_length_in_seconds}S\" endTime=\"$stopdate\"/>\n";
    print {$FH} "  <repPeriod duration=\"PT${rop_length_in_seconds}S\"/>\n";
    print {$FH} "  <measType p=\"$p\">$counter</measType>\n";

    for my $measObjLdn (sort keys %value_for) {
       print {$FH} "  <measValue measObjLdn=\"$measObjLdn\">\n";
       print {$FH} "     <r p=\"$p\">$value_for{$measObjLdn}</r>\n";
       print {$FH} "  </measValue>\n";
    }
    
    print {$FH} "</measInfo>\n";
    return;
}



sub read_counters {
    my ( $counters_dir, $counters_for_ref, $formulas_for_ref ) = @_;

    my $constants;

    opendir my $DIR, $counters_dir or croak "Cannot opendir $counters_dir: $!";
    while ( defined( my $file = readdir $DIR ) ) {
        next unless $file =~ m/\.counters$/i;    # Counters files must have extension .counters

        my ($mo_type) = $file =~ m/([\w-]+)\.counters$/;
        my $counter_file = "$counters_dir/$file";
        open my $COUNTER_FH, '<', $counter_file or croak "Cannot open file $counter_file, $!";
        while (<$COUNTER_FH>) {
            chomp;
            next if m/^\s*#/ or m/^\s*$/;        # skip lines with only comments or blank
            s/#.*//;                             # throw away any comments

            if (m/^\s*_/) {                      # extract constants (must start with _ char)
                my ( $var, $value ) = split /\s*=\s*/;
                $constants .= "use constant $var => $value;\n";
            }
            else {                               # extract counter info
                my ( $var, $formula ) = split /\s*\+?=\s*/;
                $counters_for_ref->{$mo_type} .= "$var:";    # save counters per MO type

                s/(\b(?:[a-zA-Z])\w+)/\$values_for{$1}/g;    # change any word that starts with a char to hash variable
                s/\$values_for\{(int|rand|sprintf)\}/$1/g;   # restore any perl reserved words used (int or rand )
                $formulas_for_ref->{$mo_type} .= "$_; \n";   # save formulas per MO type
            }
        }
        close $COUNTER_FH or croak "Cannot close file $counter_file, $!";
    }
    closedir $DIR or croak "Cannot closedir $counters_dir: $!";

    eval "$constants" if $constants;                         # bring values of constants into local namespace

    return $constants;
}

sub print_measurement_values {
    my ( $FH, $measObjLdn, @args ) = @_;

    print {$FH} "  <measValue measObjLdn=\"$measObjLdn\">\n";
    print_counters( $FH, @args );
    print {$FH} "  </measValue>\n";

    return;
}

sub print_measurement_values_dtd {
    my ( $FH, $measObjLdn, @args ) = @_;

    print {$FH} "  <mv>\n";
    print {$FH} "  <moid>$measObjLdn</moid>\n";
    print_counters( $FH, @args );
    print {$FH} "  </mv>\n";

    return;
}

sub print_counters {
    my ( $FH, $counters_list_ref, $formulas, $mo_accumulated_ref, $key, $counter_type ) = @_;
    my $count = 1;

    eval "$formulas";    # evaluate the formulas, the results are stored in values_for hash
#                         print "\nFormulas: '$formulas'\n";
#                         print "\nValues:\n", YAML::Tiny::Dump( \%values_for );


    for my $counter ( @{$counters_list_ref} ) {
        my $value;
        if ( defined $counter_type and $counter_type eq 'PEG' ) {
            $mo_accumulated_ref->{$key}{$counter} += $values_for{$counter};    # accumulate the new values
            $mo_accumulated_ref->{$key}{$counter} %= MAX_COUNTER_VALUE;        # PEG counters roll over
            $value = $mo_accumulated_ref->{$key}{$counter};
        }
        else {
            $value = $values_for{$counter};
        }

        print {$FH} "  <r p=\"" . $count++ . "\">$value</r>\n";
    }

    #print " After:\n", YAML::Tiny::Dump( $mo_accumulated_ref );
    return;
}

sub print_counters_dtd {
    my ( $FH, $counters_list_ref, $formulas, $mo_accumulated_ref, $key, $counter_type ) = @_;
    my $count = 1;

    eval "$formulas";    # evaluate the formulas, the results are stored in values_for hash
                         #print "\nValues:\n", YAML::Tiny::Dump( \%values_for );

    for my $counter ( @{$counters_list_ref} ) {
        my $value;
        if ( defined $counter_type and $counter_type eq 'PEG' ) {
            $mo_accumulated_ref->{$key}{$counter} += $values_for{$counter};    # accumulate the new values
            $mo_accumulated_ref->{$key}{$counter} %= MAX_COUNTER_VALUE;        # PEG counters roll over
            $value = $mo_accumulated_ref->{$key}{$counter};
        }
        else {
            $value = $values_for{$counter};
        }

        print {$FH} "  <r p=\"" . $count++ . "\">$value</r>\n";
    }

    #print " After:\n", YAML::Tiny::Dump( $mo_accumulated_ref );
    return;
}

sub create_site_topology_file {
    my ( $root_mo, $site, $topology_dir, $timezone ) = @_;

    my $topology_data = <<"SITE_TOPOLOGY";
<?xml version=\"1.0\" encoding=\"UTF-8\" ?>
<!DOCTYPE model PUBLIC \"-//Ericsson NMS CIF CS//CS Filtered Export DTD//\" \"export.dtd\">
<model>
   <mo fdn=\"$root_mo,Site=$site\" mimName=\"ONRM\" mimVersion=\"5.2.0\">
      <attr name=\"userLabel\">$site</attr>
      <attr name=\"SiteId\">$site</attr>
      <attr name=\"timeZone\">$timezone</attr>
   </mo>
</model>
SITE_TOPOLOGY

    my $site_file = "$topology_dir/sites.xml";
    open my $SITE_FH, '>', $site_file or croak "Cannot open file $site_file, $!";
    print {$SITE_FH} $topology_data;
    close $SITE_FH or croak "Cannot close file $site_file, $!";
    return;
}

sub get_values_for {
   my ( $formulas ) = @_;
#   print "$formulas\n";
 
   eval "$formulas";    # evaluate the formulas, the results are stored in values_for hash
#   print "      values $_ = $values_for{$_}\n" for sort keys %values_for;# if $debug;

   return %values_for;
}




1;

__END__

$Author: eeikcoy $

$Date: 2007-09-12 10:43:34 +0100 (Wed, 12 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/lib/ENIQ/Reports.pm $

$Id: Reports.pm 55 2007-09-12 09:43:34Z eeikcoy $



# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

<Module::Name> - <One-line description of module's purpose>


=head1 VERSION

The initial template usually just has:

This documentation refers to <Module::Name> version 0.0.1.


=head1 SYNOPSIS

    use <Module::Name>;
    # Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.


=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.
(See also "Documenting Errors" in Chapter 13.)


=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.
(See also "Configuration Files" in Chapter 19.)


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.


=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

The initial template usually just has:

There are no known bugs in this module.
Please report problems to <Maintainer name(s)>  (<contact address>)
Patches are welcome.

=head1 AUTHOR

<Author name(s)> (<contact address>)



=head1 LICENSE AND COPYRIGHT

Copyright (c) <year> <copyright holder> (<contact address>). All rights reserved.

followed by whatever licence you wish to release it under.
For Perl code that is often just:

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


