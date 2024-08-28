# The template file for MSC node configuration has some configurable values,
# and some placeholders that must be populated.
#
# The format is <name> = <value>
#
# Comment lines start with #
# Blank lines are ignored
# Blank spaces are ignored before the value, but are allowed in the value itself, e.g. see FILE_FORMAT_VERSION 
# Values with multiple instances are comma separated
#
#########################################################################################
# MSC_TYPE must be set to either:
#   Classic-CP to represent the original standalone AXE MSC node (This is the default)
#   Multi-CP   to represent the blade clustered MSC node
#
# For details, see "Statistical Counter Management", 1553-CXA 117 0028 Uen D  
#
#########################################################################################
# PROVISIONING_MODE must be set to either:
#   CP-Level      generates output files containing counter data for each CP
#   Cluster-Level generates output files containing counter data for each CP, and cluster (This is the default)
#
# For details, see "Statistical Counter Management", 1553-CXA 117 0028 Uen D  
#
# The CLUSTER field is optional depending on how the provisioning is configured.
#
# 1.4.3.4   Measurement Program
# On Multi-CP System, the available provisioning modes are “CP Level” and “Cluster Level”. The provisioning mode “CP Level” generates 
# output files containing counter data for each CP. The provisioning mode “Cluster Level” generates output files containing Cluster Level 
# counter data in addition to the output files containing CP Level counter data.
#
# In the case that provisioning is set to “CP Level” it seems that there would only be information per blade, and not aggregated to cluster.
#
#########################################################################################
# NE_DISTINGUISHED_NAME has some placeholders that must be set to suitable values.
# 
# NE_DISTINGUISHED_NAME = Exchange Identity=<EXCHANGE-ID>,Object Type=<OBJECT-TYPE>
# where the two placeholders are:
#  <EXCHANGE-ID>
#  <OBJECT-TYPE>
#
