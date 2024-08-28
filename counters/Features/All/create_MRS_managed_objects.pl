#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy for MRSs in a Core network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# An MRS is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/ManagedElement=mrs_01
#
#[TODO] Fix this whole description
#
#
# 
# Call the script with a -c argument to start with a new model structure.
# Note that all accumulated counters with history will be reset if -c is used.
#
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::DataGeneration;
use YAML::Tiny;
use File::Path;
use Carp;
use Getopt::Long;
use Storable qw(dclone);

my $usage = <<"USAGE";
 This script creates a Managed Object Model file structure for a Network Analytics Server test model.

 Usage:
        $0 [options]

    -c, --clean
                clean the old directories (if any)
    -d, --debug
                output debug information
    -h, --help
                display this help and exit
    -v, --verbose
                output additional information

 Example:
        $0 

 will create the Managed Object Model.

USAGE

my $clean      	= '';
my $debug      	= '';
my $help       	= '';
my $verbose    	= ''; # default is off

GetOptions(
   'clean'        => \$clean,
   'debug'        => \$debug,
   'help'         => \$help,
   'verbose'      => \$verbose,
);

if ($help) {
   print "$usage\n\n\n";
   exit;
}

my $root_mo  = 'ONRM_RootMo';
my $root_dir = '/eniq/home/dcuser/ManagedObjects';

my @config_sections       = qw(ATTRIBUTES METADATA);
my $config_sections_match = "@config_sections";  # create a regex match pattern
$config_sections_match    =~ s/ /|/g;

# Remove old paths they exist and if --clean argument given
clean_old_paths(root_dir => $root_dir, node_prefix => 'MeContext\=mrs_') if -d $root_dir and $clean;


my %node_model = (
   # These DEFAULT attributes are the CONFIGURATIONs for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ATTRIBUTES                => {
         daylightSavingsAdjust              => 1,
         fileFormatVersion                  => '32.401 V6.2',
         licenseCapacityAudioConferencing   => 1000, # these license values are coordinated with the expressions in MrfpFunction.counters and BorderGatewayFunction.counters
         licenseCapacityBgf                 => 1000,
         licenseCapacityHDVoiceTrans        => 1000,
         licenseCapacityHdVideoConferencing => 1000,
         licenseCapacityMrfp                => 1000,
         licenseCapacityVideo               => 1000,
         licenseCapacityVideoConferencing   => 1000,
         licenseCapacityVoiceTrans          => 1000,
         managedElementType                 => 'MGW,Bgf,Mrfp,Mrfc,Im-Mgw,Mgw,Mrfc',
         neMIMversion                       => '14.2.5',
         nodeVersion                        => '17A',
         siteRef                            => '200000',
         swVersion                          => 'CXP9018138/5_R334A04',
         timeZone                           => '+0100',
         vendorName                         => 'Ericsson',
         worldTimeZoneId                    => 'Europe/Dublin',
      },
      METADATA                 => {
         BgfApplication             => [1],
         BorderGatewayFunction      => [1],
         Equipment                  => [1],
         GENERATION                 => 'G1',
         ManagedElement             => [1],
         MgwApplication             => [1],
         MrfcApplication            => [1 .. 3],
         MrfpApplication            => [1 .. 3],
         MrfcFunction               => [1],
         MrfpFunction               => [1],
         MRFP_DIR                   => 'dim_e_mrsutil',    # location of the MRFPLic.txt file containing license parameters
         PlugInUnit                 => [1],
         OSS_ID                     => 'eniq_oss_1',
         OUTPUT_DIR                 => 'EMRS',
         PREFIX                     => 'mrs_',
         REPORTING                  => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                   => $root_dir,
         ROOT_MO                    => $root_mo,
         ROP_LENGTH                 => 900,
         Slot                       => [1 .. 20],
         Subrack                    => ['MAIN', 'CTRL', 'MSE1', 'MSE2'],
         SUBNETWORK                 => 'EPC',
         TOPOLOGY_DIR               => 'core/topologyData/CELLO',
         Vbgf                       => [1],
         Vmrfc                      => [1 .. 8],
         Vmrfp                      => [1 .. 5],
         Vmgw                       => [1],
         VppUnit                    => [1],
      },
   },
   Group_1 => {
      # These CONFIGURATION attributes are the overridden local versions
      Instances                => [1 .. 5],
   },
);



#print "node_model :\n", YAML::Tiny::Dump( \%node_model ) if $debug;


for my $grouping (sort keys %node_model) {
   next if $grouping eq 'CONFIGURATION';
   #   my %parameters = %{ $node_model{CONFIGURATION} };                                        # set default values
   my %parameters = %{ dclone($node_model{CONFIGURATION}) };                                        # set default values
   
   for my $config (keys %{ $node_model{$grouping}{CONFIGURATION} }) {
      next if $config =~ m/$config_sections_match/;
      $parameters{CONFIGURATION}{$config} = $node_model{$grouping}{CONFIGURATION}{$config}; # override with local grouping parameters
   }

   for my $config_section (@config_sections) {
      $parameters{$config_section}{$_} = $node_model{$grouping}{CONFIGURATION}{$config_section}{$_} for keys %{ $node_model{$grouping}{CONFIGURATION}{$config_section} }; # override with local grouping parameters
   }

   for my $node_index (@{ $node_model{$grouping}{Instances} } ) {
      create_managed_objects($node_index, %parameters);
   }
}

exit 0;

#
# Subroutines
#
#
sub create_managed_objects {
   my ($node_index, %parameters) = @_;

   my $node_id = sprintf "$parameters{METADATA}{PREFIX}%02d", $node_index;
   print "node_id             = $node_id\n" if $debug;
   print "  parameters :\n", YAML::Tiny::Dump( \%parameters ) if $debug;

   my $node_dir  = "$root_dir/SubNetwork=$parameters{METADATA}{ROOT_MO}/SubNetwork=$parameters{METADATA}{SUBNETWORK}/MeContext=$node_id"; 
   my $node_file = "$node_dir/$node_id.conf";
   print "node_dir  = $node_dir\n" if $debug;
   print "node_file = $node_file\n" if $debug;

   mkpath($node_dir) unless -d $node_dir;

   my %file_parameters;
   $file_parameters{$_} = $parameters{$_} for (@config_sections);
   # Create the configuration file for each node
   my $yaml = YAML::Tiny->new( \%file_parameters );
   $yaml->write( $node_file );

   print "  Model :\n", YAML::Tiny::Dump( \%{ $parameters{ManagedElement} } ) if $debug;

   # ManagedElement MOs
   for my $ManagedElement (@{ $parameters{METADATA}{ManagedElement} } ) {
      print "            ManagedElement             = $ManagedElement\n" if $debug;
      my $ManagedElement_dir = "$node_dir/ManagedElement=$ManagedElement";
      mkpath($ManagedElement_dir) unless -d $ManagedElement_dir;
      
      # MgwApplication MOs
      for my $MgwApplication (@{ $parameters{METADATA}{MgwApplication} } ) {
         print "\n            $MgwApplication             = $MgwApplication\n" if $debug;
         my $MgwApplication_dir = "$ManagedElement_dir/MgwApplication=$MgwApplication";
         mkpath($MgwApplication_dir) unless -d $MgwApplication_dir;

         # Vmgw MOs 
         for my $Vmgw (@{ $parameters{METADATA}{Vmgw} } ) {
            print "\n            $Vmgw             = $Vmgw\n" if $debug;
            my $Vmgw_dir = "$MgwApplication_dir/Vmgw=$Vmgw";
            mkpath($Vmgw_dir) unless -d $Vmgw_dir;
         }
      }

      # MrfpFunction MOs
      for my $MrfpFunction (@{ $parameters{METADATA}{MrfpFunction} } ) {
         print "\n            $MrfpFunction             = $MrfpFunction\n" if $debug;
         my $MrfpFunction_dir = "$ManagedElement_dir/MrfpFunction=$MrfpFunction";
         mkpath($MrfpFunction_dir) unless -d $MrfpFunction_dir;

         # MrfpApplication MOs 
         for my $MrfpApplication (@{ $parameters{METADATA}{MrfpApplication} } ) {
            print "\n            $MrfpApplication             = $MrfpApplication\n" if $debug;
            my $MrfpApplication_dir = "$MrfpFunction_dir/MrfpApplication=$MrfpApplication";
            mkpath($MrfpApplication_dir) unless -d $MrfpApplication_dir;

            # Vmrfp MOs 
            for my $Vmrfp (@{ $parameters{METADATA}{Vmrfp} } ) {
               print "\n            $Vmrfp             = $Vmrfp\n" if $debug;
               my $Vmrfp_dir = "$MrfpApplication_dir/Vmrfp=$Vmrfp";
               mkpath($Vmrfp_dir) unless -d $Vmrfp_dir;
            }
         }
      }

      # MrfcFunction MOs
      for my $MrfcFunction (@{ $parameters{METADATA}{MrfcFunction} } ) {
         print "\n            $MrfcFunction             = $MrfcFunction\n" if $debug;
         my $MrfcFunction_dir = "$ManagedElement_dir/MrfcFunction=$MrfcFunction";
         mkpath($MrfcFunction_dir) unless -d $MrfcFunction_dir;

         # MrfcApplication MOs 
         for my $MrfcApplication (@{ $parameters{METADATA}{MrfcApplication} } ) {
            print "\n            $MrfcApplication             = $MrfcApplication\n" if $debug;
            my $MrfcApplication_dir = "$MrfcFunction_dir/MrfcApplication=$MrfcApplication";
            mkpath($MrfcApplication_dir) unless -d $MrfcApplication_dir;

            # Vmrfc MOs 
            for my $Vmrfc (@{ $parameters{METADATA}{Vmrfc} } ) {
               print "\n            $Vmrfc             = $Vmrfc\n" if $debug;
               my $Vmrfc_dir = "$MrfcApplication_dir/Vmrfc=$Vmrfc";
               mkpath($Vmrfc_dir) unless -d $Vmrfc_dir;
            }
         }
      }

      # BorderGatewayFunction MOs
      for my $BorderGatewayFunction (@{ $parameters{METADATA}{BorderGatewayFunction} } ) {
         print "\n            $BorderGatewayFunction             = $BorderGatewayFunction\n" if $debug;
         my $BorderGatewayFunction_dir = "$ManagedElement_dir/BorderGatewayFunction=$BorderGatewayFunction";
         mkpath($BorderGatewayFunction_dir) unless -d $BorderGatewayFunction_dir;

         # BgfApplication MOs 
         for my $BgfApplication (@{ $parameters{METADATA}{BgfApplication} } ) {
            print "\n            $BgfApplication             = $BgfApplication\n" if $debug;
            my $BgfApplication_dir = "$BorderGatewayFunction_dir/BgfApplication=$BgfApplication";
            mkpath($BgfApplication_dir) unless -d $BgfApplication_dir;

            # Vbgf MOs 
            for my $Vbgf (@{ $parameters{METADATA}{Vbgf} } ) {
               print "\n            $Vbgf             = $Vbgf\n" if $debug;
               my $Vbgf_dir = "$BgfApplication_dir/Vbgf=$Vbgf";
               mkpath($Vbgf_dir) unless -d $Vbgf_dir;
            }

         }
      }

      # Equipment MOs
      for my $Equipment (@{ $parameters{METADATA}{Equipment} } ) {
         print "\n            $Equipment             = $Equipment\n" if $debug;
         my $Equipment_dir = "$ManagedElement_dir/Equipment=$Equipment";
         mkpath($Equipment_dir) unless -d $Equipment_dir;

         # Subrack MOs 
         for my $Subrack (@{ $parameters{METADATA}{Subrack} } ) {
            print "\n            $Subrack             = $Subrack\n" if $debug;
            my $Subrack_dir = "$Equipment_dir/Subrack=$Subrack";
            mkpath($Subrack_dir) unless -d $Subrack_dir;

            # Slot MOs 
            for my $Slot (@{ $parameters{METADATA}{Slot} } ) {
               print "\n            $Slot             = $Slot\n" if $debug;
               my $Slot_dir = "$Subrack_dir/Slot=$Slot";
               mkpath($Slot_dir) unless -d $Slot_dir;

               # PlugInUnit MOs 
               for my $PlugInUnit (@{ $parameters{METADATA}{PlugInUnit} } ) {
                  print "\n            $PlugInUnit             = $PlugInUnit\n" if $debug;
                  my $PlugInUnit_dir = "$Slot_dir/PlugInUnit=$PlugInUnit";
                  mkpath($PlugInUnit_dir) unless -d $PlugInUnit_dir;

                  # VppUnit MOs 
                  for my $VppUnit (@{ $parameters{METADATA}{VppUnit} } ) {
                     print "\n            $VppUnit             = $VppUnit\n" if $debug;
                     my $VppUnit_dir = "$PlugInUnit_dir/VppUnit=$VppUnit";
                     mkpath($VppUnit_dir) unless -d $VppUnit_dir;

                  }
               }
            }
         }
      }
   }

}

