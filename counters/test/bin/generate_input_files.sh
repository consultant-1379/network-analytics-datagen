#!/bin/bash

echo Saving existing data to backup directory
/bin/rm -rf /eniq/home/dcuser/counters/test/backup/input_data        # delete old backup directory
/usr/bin/mkdir -p /eniq/home/dcuser/counters/test/backup/input_data  # create new backup directory
/usr/bin/chmod +w -R /eniq/home/dcuser/counters/test/input_data      # set file permission to allow move
/usr/bin/mv /eniq/home/dcuser/counters/test/{input_data,backup}      # do the move

echo Creating input directory
/usr/bin/mkdir -p /eniq/home/dcuser/counters/test/input_data

echo Generating input counter files
/eniq/home/dcuser/counters/bin/generate_axe_counter_files.pl -a msc -f -t 0000 -s 1970-01-01 -e 1970-01-01
/eniq/home/dcuser/counters/bin/generate_cscf_counter_files.pl          -t 0000 -s 1970-01-01 -e 1970-01-01
/eniq/home/dcuser/counters/bin/generate_erbs_counter_files.pl          -t 0000 -s 1970-01-01 -e 1970-01-01
/eniq/home/dcuser/counters/bin/generate_ggsn_counter_files.pl          -t 0000 -s 1970-01-01 -e 1970-01-01
/eniq/home/dcuser/counters/bin/generate_mtas_counter_files.pl          -t 0000 -s 1970-01-01 -e 1970-01-01
/eniq/home/dcuser/counters/bin/generate_sbg_counter_files.pl           -t 0000 -s 1970-01-01 -e 1970-01-01
/eniq/home/dcuser/counters/bin/generate_sgsn_mme_counter_files.pl      -t 0000 -s 1970-01-01 -e 1970-01-01

echo Moving to input directory
/usr/bin/mv /eniq/data/pmdata/eniq_oss_1 /eniq/home/dcuser/counters/test/input_data

echo Setting file permissions to read only
/usr/bin/chmod -w -R /eniq/home/dcuser/counters/test/input_data

echo Done
