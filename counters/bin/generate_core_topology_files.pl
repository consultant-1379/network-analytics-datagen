#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Carp;

#use YAML::Tiny;

# Generates Core topology files for IMS, M-MGw, MSC, SGSN, Pool and Site
#
my $debug = 0;

my %node_info_for = (
   MSC => {
      topology => 'AXE',
      oss      => 'eniq_oss_1',
      element  => 'ManagedElement=<moid>',
      source_type => 'MSC',
      members  => {
         '15A' => [ 'msc_01', 'msc_02' ],# ensure these are consistent with those created using generate_axe_counter_files.pl
         '15B' => [ 'msc_03', 'msc_05' ],
         '16A' => [ 'msc_04' ],
      }
   },

   MSCServer => {
      topology => 'MSCCluster',
      oss      => 'eniq_oss_1',
      element  => 'ManagedElement=<moid>',
      blades   => 'BC0,BC1,BC2',
      members  => {
         '15A' => [ 'msc_06', 'msc_07' ],# ensure these are consistent with those created using generate_msc_counter_files.pl
         '15B' => [ 'msc_08', 'msc_09' ],
         '16A' => [ 'msc_10' ],
      }
   },

#   SASN => {
#      topology  => 'CoreNetwork',
#      oss       => 'eniq_oss_1',
#      element   => 'ManagedElement=<moid>',
#      members   => {
#         'R4.5' => [ 'sasn01' .. 'sasn10' ],
#      }
#   },

#   MGW => {
#      topology  => 'CELLO',
#      oss       => 'eniq_oss_1',
#      element   => 'MeContext=<moid>,ManagedElement=1',
#      members   => {
#         'R4.2' => [ 'mgw01' .. 'mgw10' ],
#         'R5.0' => [ 'mgw11' .. 'mgw20' ],
#      }
#   },

   CSCF => {
      topology => 'CoreNetwork',
      oss      => 'eniq_oss_2',
      element  => 'ManagedElement=<moid>',
      source_type => 'CSCF',
      members  => {
         '16B' => [ 'cscf_10', 'cscf_11', 'cscf_12', 'cscf_13', 'cscf_14', 'cscf_15', 'cscf_16', 'cscf_17', 'cscf_18', 'cscf_19' ],
         '17A' => [ 'cscf_20', 'cscf_21', 'cscf_22', 'cscf_23', 'cscf_24' ],
         '17B' => [ 'cscf_25', 'cscf_26', 'cscf_27', 'cscf_28', 'cscf_29' ],
      }
   }, 

#   SBG => {
#      topology => 'CoreNetwork',
#      oss      => 'eniq_oss_1',
#      element  => 'ManagedElement=<moid>',
#      members  => {
#         '3.1' => [ 'sbg_01', 'sbg_02' ],
#         '15B' => [ 'sbg_03', 'sbg_04', 'sbg_05' ],
#      }
#   }, 

   MTAS => {
      topology => 'CoreNetwork',
      oss      => 'eniq_oss_1',
      element  => 'ManagedElement=<moid>',
      source_type => 'MTAS',
      members  => {
         '16B' => [ 'mtas_10', 'mtas_11', 'mtas_12', 'mtas_13' ],
         '17A' => [ 'mtas_14', 'mtas_15', 'mtas_16' ],
         '17B' => [ 'mtas_17', 'mtas_18', 'mtas_19' ],
         '18A' => [ 'mtas_20', 'mtas_21', 'mtas_22', 'mtas_23', 'mtas_24', 'mtas_25', 'mtas_26', 'mtas_27', 'mtas_28', 'mtas_29' ],
      }
   }, 

#   SGSN => {
#      topology => 'CoreNetwork',
#      oss      => 'eniq_oss_1',
#      element  => 'ManagedElement=<moid>',
#      members  => {
#         '15B' => [ 'sgsn_01', 'sgsn_02', 'sgsn_05' ],  # ensure these are consistent with those created using generate_sgsn_counter_files.pl
#         '16A' => [ 'sgsn_03', 'sgsn_04' ],
#      }
#   },

#   MME => {
#      topology => 'CoreNetwork',
#      oss      => 'eniq_oss_1',
#      element  => 'ManagedElement=<moid>',
#      members  => {
#         '15B' => [ 'sgsn_mme_01', 'sgsn_mme_03', 'sgsn_mme_05' ],  # ensure these are consistent with those created using generate_sgsn_mme_counter_files.pl
#         '16A' => [ 'sgsn_mme_02', 'sgsn_mme_04' ],
#      }
#   },

   GGSN => {
      topology => 'CoreNetwork',
      oss      => 'eniq_oss_3',
      element  => 'ManagedElement=<moid>',
      source_type => 'GGSN',
      members  => {
         '15B' => [ 'ggsn_01', 'ggsn_05' ],  # ensure these are consistent with those created using generate_ggsn_counter_files.pl
         '16A' => [ 'ggsn_02', 'ggsn_03', 'ggsn_04' ],
      }
   },

   WMG => {
      topology => 'CoreNetwork',
      oss      => 'eniq_oss_1',
      element  => 'ManagedElement=<moid>',
      source_type => 'WMG',
      members  => {
         '15B' => [ 'wmg_01', 'wmg_05' ],  # ensure these are consistent with those created using generate_wmg_counter_files.pl
         '16A' => [ 'wmg_02', 'wmg_03', 'wmg_04' ],
      }
   },

#   POOL => {
#      topology => 'Pool',
#      oss      => 'eniq_oss_1',
#      element  => 'Group=<moid>',
#      members  => {
#         pool01 => [ 'sgsn01' .. 'sgsn04' ],
#         pool02 => [ 'sgsn05' .. 'sgsn10' ],
#         pool03 => [ 'sgsn11' .. 'sgsn13' ],
#         pool04 => [ 'sgsn14' .. 'sgsn20' ],
#         pool05 => [ 'sgsn21' .. 'sgsn40' ],
#      }
#   },

   SDC => {
      topology => 'CoreNetwork',
      oss      => 'eniq_oss_1',
      source_type => 'IPPROBE',
      element  => 'ManagedElement=<moid>',
      members  => {
         '17A' => [ 'sdc_01', 'sdc_02', 'sdc_03', 'sdc_04', 'SDC-1' ],
      }
   },

   SAPC => {
      topology => 'CoreNetwork',
      oss      => 'eniq_oss_1',
      element  => 'ManagedElement=<moid>',
      source_type => 'SAPC',
      members  => {
         '16B' => [ 'sapc_01', 'sapc_02' ],
         '17A' => [ 'sapc_03', 'sapc_04', 'sapc_05' ],
      }
   }, 


);

my ( $timezone, $not_used, $site, $root_mo ) = get_config_data();

for my $ne_type ( keys %node_info_for ) {
   print "NE type = $ne_type\n" if $debug;

   my $oss_id            = $node_info_for{$ne_type}{oss};
   my $site_topology_dir = "/eniq/data/pmdata/$oss_id/core/topologyData/Site";
   create_pmdata_dirs($site_topology_dir);
   create_site_topology_file( $root_mo, $site, $site_topology_dir, $timezone );

   my $topology_dir = "/eniq/data/pmdata/$oss_id/core/topologyData/$node_info_for{$ne_type}{topology}";
   create_pmdata_dirs($topology_dir);
   print "topology_dir = $topology_dir\n" if $debug;
   
   my $association_dir  = "/eniq/data/pmdata/$oss_id/core/topologyData/MSCClusterAssoc";
   my $association_file = "$association_dir/MSCClusterMFAssociation";
   my $association_data;

   create_pmdata_dirs($association_dir);
   print "association_dir  = $association_dir\n" if $debug;
   print "association_file = $association_file\n" if $debug;

   for my $version_or_pool_id ( sort keys %{ $node_info_for{$ne_type}{members} } ) {
      print "NE version = $version_or_pool_id\n" if $debug;
      my @ne_ids = @{ $node_info_for{$ne_type}{members}{$version_or_pool_id} };    # get all NEs with that version, or in that pool
      print "Instances = @ne_ids\n" if $debug;

      for my $ne_id (@ne_ids) {

         print "NE id = $ne_id\n" if $debug;

         my $fdn = "$root_mo,$node_info_for{$ne_type}{element}";

         if ( $ne_type eq 'POOL' ) {
            $fdn =~ s/<moid>/$version_or_pool_id/mx;

            my $pool_member_id = "$root_mo,$node_info_for{SGSN}{element}";
            $pool_member_id =~ s/<moid>/$ne_id/mx;

            my $topology_file = "$topology_dir/SubNetwork_ONRM_RootMo_ManagedElement_${version_or_pool_id}_$ne_id.xml";
            my $topology_data = pool_topology( $fdn, $version_or_pool_id, $pool_member_id );
            print_topology_data( $topology_file, $topology_data );
         }
#         elsif ($ne_type =~ /SBG/) {
#            $fdn =~ s/<moid>/$ne_id/mx;
#
#            my $topology_file = "$topology_dir/$fdn.xml";
#            $topology_file =~ s/[,=]/_/gmx;    # replace any ',' or '=' chars with '_'
#
#            my $topology_data;
#            if ($version_or_pool_id eq '3.1') { # managedElementType (NE_TYPE) for SBG nodes is Isite (not SBG) for version 3.1
#               $topology_data = sbg_topology( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id );
#            }
#            else {
#               $topology_data = sbg_topology_ecim( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id );
#            }
#            print_topology_data( $topology_file, $topology_data );
#
#         }
         elsif ($ne_type =~ /CSCF|MTAS/) {
            $fdn =~ s/<moid>/$ne_id/mx;

            my $topology_file = "$topology_dir/$fdn.xml";
            $topology_file =~ s/[,=]/_/gmx;    # replace any ',' or '=' chars with '_'
            my ($ims_type) = $ne_id =~ m/^(\D+)_\d/;
            print "IMS Type = $ims_type\n" if $debug;

#            $fdn = "DC=$ne_id.ericsson.se,g3SubNetwork=Athlone,g3ManagedElement=$ne_id" if $ne_id =~ m/^cscf/;
            my $topology_data = ims_topology( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id, $ne_type, $ims_type );
            print_topology_data( $topology_file, $topology_data );

         }
#         elsif ($ne_type eq 'MME') {
#            $fdn =~ s/<moid>/$ne_id/mx;
#
#            my $topology_file = "$topology_dir/$fdn.xml";
#            $topology_file =~ s/[,=]/_/gmx;    # replace any ',' or '=' chars with '_'
#            my $topology_data = ims_topology( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id, 'SGSN', $ne_type );
#            print_topology_data( $topology_file, $topology_data );
#         }
         elsif ($ne_type eq 'GGSN') {
            $fdn =~ s/<moid>/$ne_id/mx;

            my $topology_file = "$topology_dir/$fdn.xml";
            $topology_file =~ s/[,=]/_/gmx;    # replace any ',' or '=' chars with '_'
            my ($ne_type) = $ne_id =~ m/^(\D+)_\d/; 
            print "NE Type = $ne_type\n" if $debug;
            my $topology_data = ggsn_topology( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id, uc($ne_type) );
            print_topology_data( $topology_file, $topology_data );
         }
         elsif ($ne_type eq 'MSCServer') {
            $fdn =~ s/<moid>/$ne_id/mx;

            my $topology_file = "$topology_dir/$fdn.xml";
            $topology_file =~ s/[,=]/_/gmx;    # replace any ',' or '=' chars with '_'
            my $topology_data = msc_server_topology( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id );
            print_topology_data( $topology_file, $topology_data );

            # MSCServer also needs Associations for blades
            my @blade_list = split ',', $node_info_for{$ne_type}{blades};
            print "      BLADE_LIST  = $node_info_for{$ne_type}{blades}\n" if $debug;

            for my $blade (@blade_list) {
               $association_data .= "MSCServer|$fdn|MSCServer|$fdn,MscServerFunction=$blade\n";
            }
         }
         else {
            $fdn =~ s/<moid>/$ne_id/mx;

            my $topology_file = "$topology_dir/$fdn.xml";
            $topology_file =~ s/[,=]/_/gmx;    # replace any ',' or '=' chars with '_'
            my $topology_data = ne_topology( $fdn, $ne_id, "$root_mo,Site=$site", $version_or_pool_id, $ne_type, $node_info_for{$ne_type}{source_type} );
            print_topology_data( $topology_file, $topology_data );
         }

         print_association_data( $association_file, $association_data ) if $ne_type eq 'MSCServer';
      }
   }
}

sub print_topology_data {
   my ( $topology_file, $topology_data ) = @_;

   open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
   print {$TOPOLOGY_FH} topology_header(), "\n";
   print {$TOPOLOGY_FH} $topology_data;
   print {$TOPOLOGY_FH} topology_footer(), "\n";
   close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
}

sub print_association_data {
   my ( $association_file, $association_data ) = @_;

   open my $ASSOCIATION_FH, '>', $association_file or croak "Cannot open file $association_file, $!";
   print {$ASSOCIATION_FH} "sourceType|sourceFDN|targetType|targetFDN\n";
   print {$ASSOCIATION_FH} $association_data;
   close $ASSOCIATION_FH or croak "Cannot close file $association_file, $!";
}


sub pool_topology {
   my ( $fdn, $ne_id, $instance ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="5.0">
      <attr name="userLabel">$ne_id</attr>
      <attr name="GroupId">$ne_id</attr>
      <attr name="groupType">SGSNInPool</attr>
      <attr name="poolMember">$instance</attr>
   </mo>

NE_TOPOLOGY
}

sub ims_topology {
   my ($fdn, $ne_id, $site, $version, $ne_type, $ims_type ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="5.0">
      <attr name="userLabel">$ne_id</attr>
      <attr name="nodeVersion">$version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="managedElementType">
        <seq count="2">
          <item>$ne_type</item>
          <item>$ims_type</item>
        </seq>
      </attr>
   </mo>

NE_TOPOLOGY
}

sub ne_topology {
   my ( $fdn, $ne_id, $site, $version, $ne_type, $source_type ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="5.0">
      <attr name="userLabel">$ne_id</attr>
      <attr name="nodeVersion">$version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="sourceType">$source_type</attr>
      <attr name="managedElementType">
        <seq count="1">
          <item>$ne_type</item>
        </seq>
      </attr>
   </mo>

NE_TOPOLOGY
}

sub ggsn_topology {
   my ( $fdn, $ne_id, $site, $version, $ne_type ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="13.2.4">
      <attr name="sourceType">
        <seq count="1">
        <item>SSR8020</item>
        </seq>
      </attr>
      <attr name="userLabel">$ne_id</attr>
      <attr name="nodeVersion">$version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="managedElementType">
        <seq count="1">
          <item>$ne_type</item>
        </seq>
      </attr>
      <attr name="managedFunctionType">
       <seq count="4">
         <item>GGSN</item>
         <item>PGW</item>
         <item>SGW</item>
         <item>MBMSGW</item>
       </seq>
      </attr>
   </mo>

NE_TOPOLOGY
}

sub sbg_topology {
   my ( $fdn, $ne_id, $site, $version ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="14.2.5">
      <attr name="sourceType">
        <seq count="1">
        <item>ISBlade</item>
        </seq>
      </attr>
      <attr name="userLabel">$ne_id</attr>
      <attr name="nodeVersion">$version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="managedElementType">
        <seq count="1">
          <item>Isite</item>
        </seq>
      </attr>
   </mo>

NE_TOPOLOGY
}

sub sbg_topology_ecim {
   my ( $fdn, $ne_id, $site, $version ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="14.2.5">
      <attr name="sourceType">
        <seq count="1">
        <item>ISBlade</item>
        </seq>
      </attr>
      <attr name="userLabel">$ne_id</attr>
      <attr name="nodeVersion">$version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="managedElementType">
        <seq count="2">
          <item>SBG</item>
          <item>vInfra</item>
        </seq>
      </attr>
   </mo>

NE_TOPOLOGY
}


sub msc_server_topology {
   my ( $fdn, $ne_id, $site, $version ) = @_;
   return <<"NE_TOPOLOGY";
   <mo fdn="$fdn" mimName="ONRM" mimVersion="14.3.6">
      <attr name="sourceType">
        <seq count="1">
        <item>ISBladeHybrid</item>
        </seq>
      </attr>
      <attr name="userLabel">$ne_id</attr>
      <attr name="nodeVersion">$version</attr>
      <attr name="siteRef">$site</attr>
      <attr name="managedElementType">
        <seq count="1">
          <item>MSCServer</item>
        </seq>
      </attr>
   </mo>

NE_TOPOLOGY
}



__END__

$Author: eeikcoy $

$Date: 2008-04-25 13:58:43 +0100 (Thu, 06 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_core_topology_files.pl $

$Id: generate_core_topology_files.pl 50 2008-04-25 12:58:43Z eeikcoy $


=head1 NAME

generate_core_topology_files - creates the ENIQ topology directories and files for Core nodes: MSC, M-MGw, IMS and SGSN.

It also creates the SGSN pools.

=head1 VERSION

This documentation refers to generate_core_topology_files.pl version 1.1.

=head1 USAGE

No arguments required, just run using the command:

=over 

=item    generate_core_topology_files.pl

=back

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

None

=head1 DESCRIPTION

This script creates all the topology information needed for the ENIQ Core nodes.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/AXE

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/CELLO

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/CoreNetwork

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/Pool

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/Site

=back

=head2 MSC

The MSC topology files are stored in the AXE directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/AXE/SubNetwork_ONRM_RootMo_ManagedElement_msc01.xml

=back

=head2 M-MGw

The M-MGw topology files are stored in the CELLO directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/CELLO/SubNetwork_ONRM_RootMo_MeContext_mgw01_ManagedElement_1.xml

=back

=head2 IMS

The IMS topology files are stored in the CoreNetwork directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/CoreNetwork/SubNetwork_ONRM_RootMo_ManagedElement_ims01.xml

=back

=head2 SGSN

The SGSN topology files are stored in the CoreNetwork directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/CoreNetwork/SubNetwork_ONRM_RootMo_ManagedElement_sgsn01.xml

=back

=head2 SGSN Pool

The SGSN Pool topology files are stored in the Pool directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/Pool/SubNetwork_ONRM_RootMo_ManagedElement_pool01_sgsn01.xml

=back

=head2 Site

The Site topology files are stored in the Site directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/core/topologyData/Site/sites.xml

=back


=head1 DIAGNOSTICS

None

=head1 ENVIRONMENT

None

=head1 EXIT STATUS

None

=head1 CONFIGURATION

None

=head1 DEPENDENCIES

None

=head1 INCOMPATIBILITIES

None

=head1 BUGS AND LIMITATIONS

None

=head1 AUTHOR

eeikcoy

=head1 LICENSE AND COPYRIGHT

Ericsson (2007)

