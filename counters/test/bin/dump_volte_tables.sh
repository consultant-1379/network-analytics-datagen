#!/bin/bash

sql_date=$1     # The time for the SQL query
file_date=$2    # The time of the test comparision
output_dir=$3   # dir for table files

echo Dump Overview
# Dump Overview
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "UID=dc;PWD=dc" -host localhost -port 2640 -nogui "select qci_id, qci_value, measure_type, oss_id from dc_e_volte_overview_raw where datetime_id='$sql_date' order by measure_type, qci_id; output to $output_dir/dc_e_volte_overview_raw-$file_date.tsv format text delimited by '\t'"

echo Dump KPI
# Dump KPI
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "UID=dc;PWD=dc" -host localhost -port 2640 -nogui "select node_id, kpi_id, ran_sample_id, kpi_value, breach_indication, oss_id from dc_e_volte_kpi_raw where datetime_id='$sql_date' order by kpi_id, ran_sample_id, node_id; output to $output_dir/dc_e_volte_kpi_raw-$file_date.tsv format text delimited by '\t'"

echo Dump Node
# Dump Node
/eniq/sybase_iq/IQ-16_0/bin64/dbisql -c "UID=dc;PWD=dc" -host localhost -port 2640 -nogui "select * from dim_e_volte_node order by node_id; output to $output_dir/dim_e_volte_node-$file_date.tsv format text delimited by '\t'"


