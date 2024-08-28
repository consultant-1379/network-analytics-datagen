#!/bin/bash

# This script accepts one argument indicating the node type,
# and generates a counter file for one ROP period for that node type.

rop_time=`date '+%H%M'`

case $1 in
  bsc )  # AXE nodes
               /eniq/home/dcuser/counters/bin/generate_axe_counter_files.pl -a $1 -v -t $rop_time;;
  msc )  
               /eniq/home/dcuser/counters/bin/generate_msc_counter_files.pl -v -t $rop_time;;
  mgw | rnc | sgsn | ims | cscf | vcscf | sbg | erbs | mtas | vmtas | ggsn | sgsn_mme | wmg | sapc | vsapc )
               /eniq/home/dcuser/counters/bin/generate_$1_counter_files.pl -v -t $rop_time;;
  *)
               echo "Unknown node type $1";;
esac

