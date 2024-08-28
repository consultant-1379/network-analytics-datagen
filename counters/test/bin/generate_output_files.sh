#!/bin/bash

#set -x

# This script dumps out the VoLTE tables to text files for doing deltas between ROP periods.
# It should be called from a cron job running on the same ROP times.

# Need to find the equivalent input time.
# Offset by 15 minutes for original data to have loaded,
#           15 minutes to allow parser to run
#           15 minutes for parser's files to load
# so 900+900+900 seconds total 
#

# If a datetime is given as an argument to the script, use that, otherwise calculate an offset datetime from the current time
if [ -z "$1" ]; then
   readonly rop_datetime=`/usr/bin/perl -e "use POSIX; print strftime '%Y-%m-%d %H:%M', localtime( time - 2700 )"`
else
   readonly rop_datetime=$1
fi

echo rop_datetime = $rop_datetime

readonly file_datetime=`/usr/bin/date "+%Y%m%d_%H%M%S"`    # Save the time of the test comparision
readonly output_dir=/eniq/home/dcuser/counters/test/output_data/actual
readonly result_dir=/eniq/home/dcuser/counters/test/results
readonly sql_template=/eniq/home/dcuser/counters/test/sql/templates/dump_volte_tables.sql
readonly sql_query=/eniq/home/dcuser/counters/test/sql/dump_volte_tables.sql



# Some SYBASE environment variables needed for dbisql
export PATH=$PATH:/eniq/sybase_iq/IQ-16_0/bin64
export SYBASE=/eniq/sybase_iq/
export SQLANY=/eniq/sql_anywhere
export SQLANY16=/eniq/sql_anywhere
export SQLANY11=/eniq/sql_anywhere
 
#export SYBASE_JRE7_64=/eniq/sybase_iq/shared/SAPJRE-7_1_015_64BIT

source $SYBASE/IQ.sh
source /eniq/home/dcuser/.profile

#echo Dumping VoLTE Tables

# copy the template file
/bin/cp $sql_template $sql_query

# set the parameters
/usr/bin/perl -pi -e "s/<rop_datetime>/$rop_datetime/g; s/<file_datetime>/$file_datetime/g; s{<output_dir>}{$output_dir}g" $sql_query

# Dump the tables
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c 'UID=dc;PWD=dc' -host localhost -port 2640 -nogui $sql_query


#/eniq/home/dcuser/counters/test/bin/dump_volte_tables.sh "$sql_date" "$file_date" "$output_dir"

#echo Dump Overview
# Dump Overview
#/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c 'UID=dc;PWD=dc' -host localhost -port 2640 -nogui \
#   "select qci_id, qci_value, measure_type, oss_id from dc_e_volte_overview_raw where datetime_id='$sql_date' order by measure_type, qci_id; output to $output_dir/dc_e_volte_overview_raw-$file_date.tsv format text delimited by '\t'"

#echo Dump KPI
# Dump KPI
#/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c 'UID=dc;PWD=dc' -host localhost -port 2640 -nogui \
#   "select node_id, kpi_id, ran_sample_id, kpi_value, breach_indication, oss_id from dc_e_volte_kpi_raw where datetime_id='$sql_date' order by kpi_id, ran_sample_id, node_id; output to $output_dir/dc_e_volte_kpi_raw-$file_date.tsv format text delimited by '\t'"

#echo Dump Node
# Dump Node
#/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c 'UID=dc;PWD=dc' -host localhost -port 2640 -nogui \
#   "select * from dim_e_volte_node order by node_id; output to $output_dir/dim_e_volte_node-$file_date.tsv format text delimited by '\t'"


#
# Perform the test
#
failure_dir=$result_dir/failure
success_dir=$result_dir/success

failure_file=$failure_dir/$file_datetime.fail
success_file=$success_dir/$file_datetime.success

#echo failure_file = $failure_file
#echo success_file = $success_file


# Compare Expected vs Actual
overview_result=`SHELL=/bin/bash && /usr/bin/diff /eniq/home/dcuser/counters/test/output_data/{expected,actual}/dc_e_volte_overview*.tsv`
kpi_result=`SHELL=/bin/bash && /usr/bin/diff /eniq/home/dcuser/counters/test/output_data/{expected,actual}/dc_e_volte_kpi*.tsv`
node_result=`SHELL=/bin/bash && /usr/bin/diff /eniq/home/dcuser/counters/test/output_data/{expected,actual}/dim_e_volte_node*.tsv`

echo overview_result = $overview_result
echo 
echo kpi_result = $kpi_result
echo 
echo node_result = $node_result
echo 


if [ -z "$overview_result" ] && [ -z "$kpi_result" ] && [ -z "$node_result" ]; then
   echo "All comparisons successful" >> $success_file;
#   /bin/rm $output_dir/*.tsv     # remove the test files
   exit 0                        # and exit
fi

# One of the tests must have failed, so find out which
if [ -n "$overview_result" ]; then
   echo "Overview comparison failed\n:$overview_result\n" >> $failure_file
elif [ -n "$kpi_result" ]; then
   echo "KPI comparison failed\n:$kpi_result\n" >> $failure_file
elif [ -n "$node_result" ]; then   
   echo "Node comparison failed\n:$node_result\n" >> $failure_file
fi

# save the test files to a dir for analysis
/bin/mkdir -p $failure_dir/$file_datetime
/bin/mv $output_dir/*.tsv $failure_dir/$file_datetime  


exit 0
