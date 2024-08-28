#!/bin/bash

# This script generates a Bulk CM file for the current time.

rop_time=`date '+%Y%m%d%H%M'`

source_file=/eniq/home/dcuser/counters/etc/bulk_cm_initial.xml
target_file=/tmp/AOM901122_R2EEU03_O15.2_${rop_time}+0100_eniq_oss_1_radio.xml
target_dir=/eniq/data/pmdata/eniq_oss_1/bulkcm/dir1

mkdir -p $target_dir
cp $source_file $target_file
gzip $target_file
mv $target_file.gz $target_dir

