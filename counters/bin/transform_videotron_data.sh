#!/usr/bin/bash

# This script is used to replay real node data from Videotron.
# The data is time-shifted and anonymised.
# The current day of the month is used to fetch the data for the same day in May 2016 from the Videotron tables on atrcxb4085 for the current ROP.
#
# This script should be called from a cron job with the following settings:
#
# 0,15,30,45 * * * * /eniq/home/dcuser/counters/bin/transform_videotron_data.sh 2>&1 >> /eniq/home/dcuser/counters/log/transform_videotron_data.log

# Videotron parameters
host=ieatrcx4085.athtem.eei.ericsson.se
base_date='2016-05-01'             # Start date used as a base from which to select values

# Limit selected nodes
nodes_to_match='QU%'               # Match nodes with this 'LIKE' pattern

# Set default values
dc_release='17A'
dc_timezone='+0100'

# Define data dirs
template_dir=/eniq/home/dcuser/counters/nodes/ERBS/ETL
output_dir=/eniq/home/dcuser/ETL
nodes_file=$output_dir/nodes.csv   # Nodes file contains a list of FDNs matching the pattern 
/usr/bin/mkdir -p $output_dir      # Create the output dir if it doesn't already exist
 
# Set up some environment variables required for Sybase handling
export SYBASE=/eniq/sybase_iq
export SQLANY=/eniq/sql_anywhere
. ${SYBASE}/IQ.sh

datetime_id=$1 # take the datetime from the first argument (if any)

[ -z "$1" ] && datetime_id=`date '+%Y-%m-%d %H:%M:00'` # Set the date/time values for the current ROP

read year month day hour minute second <<< ${datetime_id//[-:]/ }
today="$year-$month-$day"
utc_datetime_id=$datetime_id       # Remember to change this for a different Timezone or Daylight Savings offset

# remove any leading zero chars
minute="${minute##0}"
hour="${hour##0}"
day="${day##0}"
month="${month##0}"

echo DATETIME_ID is $datetime_id

# Find a sample list of nodes in the Videotron set
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=$host;port=2640)" -onerror exit -nogui "SELECT ERBS_FDN FROM DIM_E_LTE_ERBS WHERE ERBS_NAME LIKE '$nodes_to_match'; OUTPUT TO $nodes_file QUOTE '' ALL"

# Loop for all required tables
for table in `/usr/bin/find $template_dir/* -type d -exec /usr/bin/basename {} \;`
do
   echo Table is $table

   /usr/bin/mkdir -p $output_dir/$table # Create the output dirs if they don't already exist

   counters=`/usr/bin/cat $template_dir/$table/counters.csv`   # read in the list of counters

   # Populate the template with values
   /usr/bin/perl -pe "s/<DATETIME_ID>/$datetime_id/g;         \
                      s/<UTC_DATETIME_ID>/$utc_datetime_id/g; \
                      s/<DATE>/$today/g;                      \
                      s/<MINUTE>/$minute/g;                   \
                      s/<HOUR>/$hour/g;                       \
                      s/<DAY>/$day/g;                         \
                      s/<MONTH>/$month/g;                     \
                      s/<YEAR>/$year/g;                       \
                      s/<BASE_DATE>/$base_date/g;             \
                      s/<DC_RELEASE>/$dc_release/g;           \
                      s/<DC_TIMEZONE>/$dc_timezone/g;         \
                      s/<NODES_TO_MATCH>/$nodes_to_match/g;   \
                      s/<TABLE>/$table/g;                     \
                      s/<COUNTERS>/$counters/g;               \
                     " $template_dir/$table/extract.sql > $output_dir/$table/extract.sql

   # Find the partition here for the current ROP
   partition=`/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dwhrep;pwd=dwhrep;eng=repdb;dbn=repdb;links=tcpip(host=localhost;port=2641)" -nogui -onerror exit "SELECT TABLENAME FROM DWHPartition WHERE STORAGEID like '$table%' AND now() >= STARTTIME and now() <= ENDTIME" | grep $table`
   echo Partition is $partition

   counters=${counters//[a-z]\.} # strip off any SQL table alias prefix

   # Set the partition in the SQL load file
   /usr/bin/perl -pe "s/<PARTITION>/$partition/g; \
                      s/<TABLE>/$table/g;         \
                      s/<COUNTERS>/$counters/g;   \
                     " $template_dir/$table/load.sql > $output_dir/$table/load.sql

   # Read the Videotron data into a file
   /eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=$host;port=2640)" -onerror exit -nogui $output_dir/$table/extract.sql

   # Anonymise the data
   /eniq/home/dcuser/counters/bin/anonymise_videotron_data.pl $nodes_file $output_dir/$table/data.csv 

   # Load the file into the table on this server
   /eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=localhost;port=2640)" -onerror exit -nogui $output_dir/$table/load.sql

done

