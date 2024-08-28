#!/bin/bash

# This script performs time shifts on all input files in 
#   /eniq/home/dcuser/counters/test/input_data/eniq_oss_1/.../dir1
# and makes them available for loading during the current ROP.
#
# Takes 1 mandatory argument and one optional argument
# First argument is node type
# Second argument is ROP period length in minutes
#

function usage {
   echo
   echo "Usage: timeshift_input_files.sh <node_type> [<rop_length>]"
   echo 
   echo "Example: timeshift_input_files.sh msc"
   echo
   echo "Accepted node types are: cscf, cscfv, erbs, erbsg2, msc, mtas, sbg, sgsn_mme"
}

if [ -z "$1" ]; then
   usage
   exit 1
fi

DEBUG=0 # set to 1 to enable or 0 to disable

function debug {
   if [ $DEBUG -eq 1 ]; then
      echo "$@"
   fi
}

node_type=$1

declare -i rop_length=900   # default ROP is 15 minutes (900 seconds)

# If ROP length argument was given, then use that value
if [ ! -z "$2" ]; then
   rop_length=60*$2    # Argument is in minutes, multiple by 60 to convert to seconds
fi

# Save the current start and end ROP date and time (HHMM)
readonly start_rop_date=`/usr/bin/perl -e "use POSIX; print strftime '%Y%m%d', localtime( time - $rop_length )"` # calculate the start date of the ROP, rop_length seconds before
readonly start_rop_time=`/usr/bin/perl -e "use POSIX; print strftime '%H%M', localtime( time - $rop_length )"`   # calculate the start time of the ROP, rop_length seconds before
readonly end_rop_date=`/usr/bin/perl -e "use POSIX; print strftime '%Y%m%d', localtime( time )"`                 # calculate the end date of the ROP
readonly end_rop_time=`/usr/bin/perl -e "use POSIX; print strftime '%H%M', localtime( time )"`                   # calculate the end time of the ROP

debug start_rop_date = $start_rop_date
debug start_rop_time = $start_rop_time
debug end_rop_date   = $end_rop_date
debug end_rop_time   = $end_rop_time
debug rop_length     = $rop_length


# Need different filename time formats for various node types
#
# Sample file names below:
#   A19700101.0000+0100-0015+0100_SubNetwork=ONRM_RootMo,MeContext=mtas_01_statsfile.xml
#   A19700101.0000+0100-19700101.0015+0100_SubNetwork=ONRM_RootMo,MeContext=sgsn_mme_01_statsfile.xml
#   A19700101.0000-0015_cscf_01_Cscf2
#   A19700101.0000-19700101.0015_msc_01
#

readonly input_file_time='A19700101.0000+0100-0015+0100'
readonly input_file_time_sgsnmme='A19700101.0000+0100-19700101.0015+0100'
readonly input_file_time_cscf='A19700101.0000-0015'
readonly input_file_time_msc='A19700101.0000-19700101.0015'
readonly current_file_time="A$start_rop_date.$start_rop_time+0100-$end_rop_time+0100"
readonly current_file_time_sgsnmme="A$start_rop_date.$start_rop_time+0100-$end_rop_date.$end_rop_time+0100"
readonly current_file_time_cscf="A$start_rop_date.$start_rop_time-$end_rop_time"
readonly current_file_time_msc="A$start_rop_date.$start_rop_time-$end_rop_date.$end_rop_time"

# Need different file contents time formats for various node types
# Note the need to prefix the plus char with backslash for use in regex
readonly input_begin_time_3gpp='1970-01-01T00:00:00\+0100'   
readonly input_end_time_3gpp='1970-01-01T00:15:00\+0100'
readonly input_begin_time_mdc='19700101000000\+0100'
readonly input_end_time_mdc='19700101001500\+0100'


# Begin and End times in MDC format (YYYYmmddHHMMSS+TZ)
readonly current_begin_time_mdc=`/usr/bin/perl -e "use POSIX; print strftime '%Y%m%d%H%M00+0100', localtime( time - $rop_length )"`       # calculate the file beginTime in mdc format 
readonly current_end_time_mdc=`/usr/bin/perl -e "use POSIX; print strftime '%Y%m%d%H%M00+0100', localtime( time )"`                       # calculate the file endTime in mdc format

# Begin and End times in 3GPP 32.435 format (YYYY-mm-ddTHH:MM:SS+TZ)
readonly current_begin_time_3gpp=`/usr/bin/perl -e "use POSIX; print strftime '%Y-%m-%dT%H:%M:00+0100', localtime( time - $rop_length )"` # calculate the file beginTime in 3GPP format 
readonly current_end_time_3gpp=`/usr/bin/perl -e "use POSIX; print strftime '%Y-%m-%dT%H:%M:00+0100', localtime( time )"`                 # calculate the file endTime in 3GPP format

debug current_begin_time_mdc  = $current_begin_time_mdc
debug current_end_time_mdc    = $current_end_time_mdc
debug current_begin_time_3gpp = $current_begin_time_3gpp
debug current_end_time_3gpp   = $current_end_time_3gpp

#
# Need a tmp directory for intermediate files
#
readonly tmp_dir=/eniq/home/dcuser/counters/test/tmp
# create tmp directory, if necessary
if [ ! -d $tmp_dir ]; then
   debug Creating tmp directory 
   /bin/mkdir -p $tmp_dir
fi

function perform_timeshift {
   readonly oss_id=$1
   readonly dir_name=$2
   readonly parser_type=$3
   readonly old_file_time=$4
   readonly new_file_time=$5
   readonly old_begin_time=$6
   readonly old_end_time=$7
   readonly new_begin_time=$8
   readonly new_end_time=$9

   debug oss_id         = $oss_id
   debug dir_name       = $dir_name
   debug old_file_time  = $old_file_time
   debug new_file_time  = $new_file_time
   debug old_begin_time = $old_begin_time
   debug old_end_time   = $old_end_time
   debug new_begin_time = $new_begin_time
   debug new_end_time   = $new_end_time

   input_dir=/eniq/home/dcuser/counters/test/input_data/eniq_oss_1/$dir_name/dir1
   output_dir=/eniq/data/pmdata/$oss_id/$dir_name/dir1
 
   # create output directory, if necessary
   if [ ! -d $output_dir ]; then
      debug Creating output directory for $dir_name
      /bin/mkdir -p $output_dir
   fi

   for file in $input_dir/*
   do
      # Change the time values in the file name
      old_file_name=$(basename $file)  # remove path
      new_file_name=${old_file_name/$old_file_time/$new_file_time}

      debug old_file_name = $old_file_name
      debug new_file_name = $new_file_name

      /bin/cp $file $tmp_dir/$new_file_name        # copy and rename the file
      /usr/bin/perl -pi -e "s/$old_begin_time/$new_begin_time/g; s/$old_end_time/$new_end_time/g; s{<gp>(300|900)</gp>}{<gp>$rop_length</gp>}g; s{duration=\"PT(300|900)S\"}{duration=\"PT${rop_length}S\"}g" $tmp_dir/$new_file_name
      /bin/rm -f $tmp_dir/*.bak                    # remove tmp file

      if [ $parser_type == 'asn1' ]; then
         # Convert to ASN.1 format
         /eniq/home/dcuser/counters/test/bin/convert_to_asn1.pl $tmp_dir/$new_file_name $output_dir 
         /bin/rm -f $tmp_dir/$new_file_name        # remove tmp file
      else
         /bin/mv $tmp_dir/$new_file_name $output_dir           # move the file to the output dir
      fi

      debug old_file = $file
      debug new_file = $output_dir/$new_file_name

   done


}

# Convert to lower case for use in switch selector
node_type=`/usr/bin/perl -e "print lc $node_type"`
debug node_type = $node_type


case "$node_type" in

   # CSCF Original   
   cscf)
      perform_timeshift eniq_oss_2 ims mdc $input_file_time_cscf $current_file_time_cscf $input_begin_time_mdc $input_end_time_mdc $current_begin_time_mdc $current_end_time_mdc
      ;;

   # CSCF Virtual
   cscfv)
      perform_timeshift eniq_oss_2 cscf 3gpp $input_file_time $current_file_time $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # LTE RAN
   erbs)
      perform_timeshift eniq_oss_1 lterbs mdc $input_file_time $current_file_time $input_begin_time_mdc $input_end_time_mdc $current_begin_time_mdc $current_end_time_mdc
      ;;

   # Radio Node
   erbsg2)
      perform_timeshift eniq_oss_1 'RadioNode/LRAT' 3gpp $input_file_time $current_file_time $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # MSC 
   msc)
      perform_timeshift eniq_oss_1 msc-iog asn1 $input_file_time_msc $current_file_time_msc $input_begin_time_mdc $input_end_time_mdc $current_begin_time_mdc $current_end_time_mdc
      ;;

   # MTAS
   mtas)
      perform_timeshift eniq_oss_1 MTAS_CBA 3gpp $input_file_time $current_file_time $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # GGSN
   ggsn)
      perform_timeshift eniq_oss_3 ggsn-mpg-xml 3gpp $input_file_time $current_file_time $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # SBG
   sbg)
      perform_timeshift eniq_oss_1 SBG 3gpp $input_file_time $current_file_time $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # SGSN MME
   sgsn_mme)
      perform_timeshift eniq_oss_1 sgsn_mme_cba 3gpp $input_file_time_sgsnmme $current_file_time_sgsnmme $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # WMG
   wmg)
      perform_timeshift eniq_oss_1 wmg 3gpp $input_file_time $current_file_time $input_begin_time_3gpp $input_end_time_3gpp $current_begin_time_3gpp $current_end_time_3gpp
      ;;

   # Error
   *)
      echo "Unknown node type $node_type"
      exit 1
      ;;

esac

