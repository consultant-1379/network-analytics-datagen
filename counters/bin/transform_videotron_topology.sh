#!/usr/bin/bash

# This script is used to convert topology data from Videotron.
# The data is anonymised.
#
# This script should be called from a cron job with the following settings:
#
#55 0 * * *         /eniq/home/dcuser/counters/bin/transform_videotron_topology.sh    2>&1 >> /eniq/home/dcuser/counters/log/transform_videotron_topology.log


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

# Videotron source files
videotron_node_fdns=$output_dir/node_fdns.csv   # Nodes file contains a list of FDNs matching the pattern 
videotron_nodes_file=$output_dir/dim_e_lte_erbs_videotron.csv
videotron_cells_file=$output_dir/dim_e_lte_eucell_videotron.csv

# Anonymised files
nodes_file=$output_dir/dim_e_lte_erbs.csv
cells_file=$output_dir/dim_e_lte_eucell.csv

# Create the output dir if it doesn't already exist
/usr/bin/mkdir -p $output_dir

# Set up some environment variables required for Sybase handling
export SYBASE=/eniq/sybase_iq
export SQLANY=/eniq/sql_anywhere
. ${SYBASE}/IQ.sh

# Find a sample list of node FDNs in the Videotron set
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=$host;port=2640)" -onerror exit -nogui "SELECT ERBS_FDN FROM DIM_E_LTE_ERBS WHERE ERBS_NAME LIKE '$nodes_to_match'; OUTPUT TO $videotron_node_fdns QUOTE '' ALL"

#
# Anonymise ERBSs
#

# Find a sample list of nodes in the Videotron set
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=$host;port=2640)" -onerror exit -nogui "select OSS_ID, ERBS_FDN, ERBS_NAME, ERBS_ID, SITE_FDN, SITE_ID, MECONTEXTID, NEMIMVERSION, '17A' as ERBS_VERSION, VENDOR, STATUS, 'ERBS' as managedElementType, '' from dim_e_lte_erbs where erbs_id like '$nodes_to_match'; output to $videotron_nodes_file delimited by '|' quote '' all"

# Remove duplicate nodes
/usr/bin/sort $videotron_nodes_file | /usr/bin/uniq > $nodes_file

# Anonymise the data
/eniq/home/dcuser/counters/bin/anonymise_videotron_data.pl $videotron_node_fdns $nodes_file

# Delete any old enb nodes from the ERBS DIM table on the local server
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=localhost;port=2640)" -onerror exit -nogui "delete from dim_e_lte_erbs where erbs_id like 'enb%'"

## Load the ERBS DIM table on the local server
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=localhost;port=2640)" -onerror exit -nogui $template_dir/load_dim_e_lte_erbs.sql

#
# Anonymise EUtranCells
#

# Find a sample list of cells in the Videotron set
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=$host;port=2640)" -onerror exit -nogui "select OSS_ID, EUTRANCELL_FDN, CELL_TYPE, ERBS_ID, ENodeBFunction, EUtranCellId, CELL_ID, TAC_NAME, tac, earfcndl, earfcnul, earfcn, userLabel, hostingDigitalUnit, noOfPucchCqiUsers, noOfPucchSrUsers, cellRange, ulChannelBandwidth, pdcchCfiMode, ERBS_FDN, VENDOR, STATUS, '' from DIM_E_LTE_EUCELL where erbs_id like '$nodes_to_match'; output to $videotron_cells_file delimited by '|' quote '' all"

# Remove duplicate cells
/usr/bin/sort $videotron_cells_file | /usr/bin/uniq > $cells_file

# Anonymise the data
/eniq/home/dcuser/counters/bin/anonymise_videotron_data.pl $videotron_node_fdns $cells_file

# Delete any old enb cells from the EUtranCell DIM table on the local server
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=localhost;port=2640)" -onerror exit -nogui "delete from dim_e_lte_eucell where erbs_id like 'enb%'"

## Load the EUtranCell DIM table on the local server
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "uid=dc;pwd=dc;eng=dwhdb;dbn=dwhdb;links=tcpip(host=localhost;port=2640)" -onerror exit -nogui $template_dir/load_dim_e_lte_eucell.sql

