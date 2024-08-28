
select qci_id, qci_value, measure_type, oss_id 
   from dc_e_volte_overview_raw 
   where datetime_id='<rop_datetime>' 
   order by measure_type, qci_id; 
   output to <output_dir>/dc_e_volte_overview_raw-<file_datetime>.tsv format text delimited by '\t';

select node_id, kpi_id, ran_sample_id, kpi_value, breach_indication, oss_id 
   from dc_e_volte_kpi_raw 
   where datetime_id='<rop_datetime>' 
   order by kpi_id, ran_sample_id, node_id; 
   output to <output_dir>/dc_e_volte_kpi_raw-<file_datetime>.tsv format text delimited by '\t';

select * 
   from dim_e_volte_node 
   order by node_id; 
   output to <output_dir>/dim_e_volte_node-<file_datetime>.tsv format text delimited by '\t';


