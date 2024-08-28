#!/bin/bash

# This script accepts one argument indicating the node type,
# and generates a counter file for one ROP period for that node type.

rop_time=`date '+%H%M'`

case $1 in
  msc | bsc )  # AXE nodes
               /eniq/home/dcuser/counters/bin/generate_axe_counter_files.pl -a $1 -v -t $rop_time;;
  mgw | rnc | sgsn | sbg | erbs | mtas | sgsn_mme )
               /eniq/home/dcuser/counters/bin/generate_$1_counter_files.pl -v -t $rop_time;;
  ims | cscf )
               /eniq/home/dcuser/counters/bin/generate_$1_counter_files.pl -v -t $rop_time -o eniq_oss_2;;
  ggsn )
               /eniq/home/dcuser/counters/bin/generate_$1_counter_files.pl -v -t $rop_time -o eniq_oss_3;;
  *)
               echo "Unknown node type $1";;
esac

