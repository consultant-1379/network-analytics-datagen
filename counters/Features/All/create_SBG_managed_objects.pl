#!/usr/bin/perl
#
# This script creates a model of the managed object hierarchy for SBGs in a Core network.
#
# Each MO is modelled by a path in the file system in the ManagedObjects directory, 
# e.g. the root MO is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo
#
# An SBG is represented by
#    ManagedObjects/SubNetwork=ONRM_RootMo/ManagedElement=sbg_01
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
clean_old_paths(root_dir => $root_dir, node_prefix => 'ManagedElement\=sbg_') if -d $root_dir and $clean;

my %mo_suffix = (
   AccessNetPcscf             => '',
   CoreNetPcscf               => '',
   NetworkQoS                 => '.netId',
   MatedPair                  => '',
   PayloadProcessor           => '',
   ProcessorManagement        => '',
   ProxyRegistrar             => '',
   ProxyRegistrarV6           => '',
   PCSCF                      => '',
   SbgFunction                => '',
   SGC                        => '.bsNo',
   SgcBlade                   => '.subrack=0+slot',
   SgcCp                      => '',
   SignalingNetworkConnection => '.netId',
   Sip                        => '.networkRole',
   SipPa                      => '',
   SipPaTermination           => '',
   SipPc                      => '',
   SipPcTermination           => '',
   SipV6                      => '.networkRole',
);

my %node_model = (
   # These DEFAULT attributes are the CONFIGURATIONs for all Managed Objects unless overridden by local versions
   CONFIGURATION => {
      ATTRIBUTES                => {
         daylightSavingsAdjust     => 1,
         fileFormatVersion         => '32.435 V8.0',
         managedElementType        => 'SBG,vInfra',
         neMIMversion              => '14.2.5',
         nodeVersion               => '16B',
         siteRef                   => '200000',
         swVersion                 => 'CXP102051/21_R38ES',
         timeZone                  => '+0100',
         vendorName                => 'Ericsson',
         worldTimeZoneId           => 'Europe/Dublin',
      },
      METADATA                 => {
         GENERATION                 => 'G2',
         NetworkQoS                 => [1, 2, 4, 5, 7],
         OSS_ID                     => 'eniq_oss_1',
         OUTPUT_DIR                 => 'SBG',
         PREFIX                     => 'sbg_',
         REPORTING                  => 1,                  # 1 = Reporting, 0 = Not Reporting 
         ROOT_DIR                   => $root_dir,
         ROOT_MO                    => $root_mo,
         ROP_LENGTH                 => 900,
         MatedPair                  => [],
         PayloadProcessor           => [],
         ProcessorManagement        => [],
         ProxyRegistrar             => ['*'],
         ProxyRegistrarV6           => [],
         SbgFunction                => [],                 # SbgFunction and subordinate MOs only needed for PayloadProcessor, leave this empty to skip all from this level down
         SGC                        => [2, 4, 6],
         SgcBlade                   => [7, 9],
         SgcCp                      => ['*'],
         SignalingNetworkConnection => [1, 4, 5],
         Sip                        => [1, 2],
         SipV6                      => [],
         SUBNETWORK                 => 'EPC',
         TOPOLOGY_DIR               => 'core/topologyData/CoreNetwork',
      },
   },
   Group_1 => {
      # These CONFIGURATION attributes are the overridden local versions
      Instances                => [1],
#      Instances                => [1..5, 20],      
   },
   Group_2 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            managedElementType        => 'Isite',
            neMIMversion              => '14.2.6',
         },
         METADATA                  => {
            SGC                       => [1 .. 3],
         },
      },
#      Instances                => [6], 
      Instances                => [],
   },
   Group_3 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            managedElementType        => 'Isite',
            neMIMversion              => '14.2.7',
         },
      },
#      Instances                => [7],
      Instances                => [],
   },
   Group_4 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            managedElementType        => 'Isite',
            neMIMversion              => '14.2.8',
         },
      },
#      Instances                => [8],
      Instances                => [],
   },
   Group_5 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            managedElementType        => 'Isite',
            neMIMversion              => '14.2.9',
         },
         METADATA                  => {
            SGC                       => [1, 2, 3, 5, 9],
         },
      },
      Instances                => [9],      
   },
   Group_6 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.10',
         },
         METADATA                  => {
            SGC                       => [1, 5, 8, 9],
         },
      },
      Instances                => [10],      
   },
   Group_7 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.11',
         },
         METADATA                  => {
            SGC                       => [10 .. 12],
            ProxyRegistrar             => [],
            ProxyRegistrarV6           => ['*'],
            Sip                        => [],
            SipV6                      => [1, 2],
         },
      },
      Instances                => [11],
   },
   Group_8 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            neMIMversion              => '14.2.12',
         },
         METADATA                  => {
            SGC                       => [1, 3, 4, 5, 8, 9],
            ProxyRegistrar             => [],
            ProxyRegistrarV6           => ['*'],
            Sip                        => [],
            SipV6                      => [1, 2],
         },
      },
      Instances                => [12],
   },
   Group_vSBG_1 => {
      # These CONFIGURATION attributes are the overridden local versions
      CONFIGURATION => {
         ATTRIBUTES                => {
            managedElementType        => 'ERIC-COREMW_RUNTIME',
            nodeVersion               => '1.6',
            neMIMversion              => '18.1.1',
            swVersion                 => 'CXP9020355_1 R10J01',
         },
         METADATA                  => {
            AccessNetPcscf             => [1, 2],
            CoreNetPcscf               => [1, 2],
            MatedPair                  => [1, 2, 3, 4],
            PayloadProcessor           => ['processor_0_7', 'processor_0_9', 'processor_0_11'],
            ProcessorManagement        => [1],
            NetworkQoS                 => [],                   # No NetworkQoS in vSBG
            OUTPUT_DIR                 => 'SBG_CBA',
            ProxyRegistrar             => [],
            ProxyRegistrarV6           => [],
            PCSCF                      => [1],
            ROP_LENGTH                 => 300,
            SbgFunction                => [1],
            SGC                        => [],
            SgcBlade                   => [],                   # No SgcBlade in vSBG
            SgcCp                      => [],                   # No SgcCp in vSBG
            SignalingNetworkConnection => [],
            Sip                        => [],
            SipPa                      => [1],
            SipPaTermination           => [1, 2, 3, 4, 8, 16],
            SipPc                      => [1],
            SipPcTermination           => [1, 2, 3, 4, 8, 16],
            SipV6                      => [],
 
          },
      },
      Instances                => [30 .. 34],
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

   my $node_dir  = "$root_dir/SubNetwork=$parameters{METADATA}{ROOT_MO}/SubNetwork=$parameters{METADATA}{SUBNETWORK}/ManagedElement=$node_id"; 
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

   # SbgFunction MOs
   for my $SbgFunction (@{ $parameters{METADATA}{SbgFunction} } ) {
      print "            SbgFunction             = $SbgFunction\n" if $debug;
      
      # PCSCF MOs
      for my $PCSCF (@{ $parameters{METADATA}{PCSCF} } ) {
         print "\n            $PCSCF             = $PCSCF\n" if $debug;
         my $SbgFunction_dir = "$node_dir/SbgFunction$mo_suffix{SbgFunction}=$SbgFunction/PCSCF$mo_suffix{PCSCF}=$PCSCF";
         mkpath($SbgFunction_dir) unless -d $SbgFunction_dir;

         # AccessNetPcscf MOs 
         for my $AccessNetPcscf (@{ $parameters{METADATA}{AccessNetPcscf} } ) {
            print "\n            $AccessNetPcscf             = $AccessNetPcscf\n" if $debug;
            my $AccessNetPcscf_dir = "$SbgFunction_dir/AccessNetPcscf$mo_suffix{AccessNetPcscf}=$AccessNetPcscf";
            mkpath($AccessNetPcscf_dir) unless -d $AccessNetPcscf_dir;

            # SipPa MOs 
            for my $SipPa (@{ $parameters{METADATA}{SipPa} } ) {
               print "\n            $SipPa             = $SipPa\n" if $debug;
               my $SipPa_dir = "$AccessNetPcscf_dir/SipPa$mo_suffix{SipPa}=$SipPa";
               mkpath($SipPa_dir) unless -d $SipPa_dir;

               for my $SipPaTermination (@{ $parameters{METADATA}{SipPaTermination} } ) {
                  print "\n            $SipPaTermination             = $SipPaTermination\n" if $debug;
                  my $SipPaTermination_dir = "$SipPa_dir/SipPaTermination$mo_suffix{SipPaTermination}=$SipPaTermination";
                  mkpath($SipPaTermination_dir) unless -d $SipPaTermination_dir;
               }
            }
         }

         # CoreNetPcscf MOs 
         for my $CoreNetPcscf (@{ $parameters{METADATA}{CoreNetPcscf} } ) {
            print "\n            $CoreNetPcscf             = $CoreNetPcscf\n" if $debug;
            my $CoreNetPcscf_dir = "$SbgFunction_dir/CoreNetPcscf$mo_suffix{CoreNetPcscf}=$CoreNetPcscf";
            mkpath($CoreNetPcscf_dir) unless -d $CoreNetPcscf_dir;

            # SipPc MOs 
            for my $SipPc (@{ $parameters{METADATA}{SipPc} } ) {
               print "\n            $SipPc             = $SipPc\n" if $debug;
               my $SipPc_dir = "$CoreNetPcscf_dir/SipPc$mo_suffix{SipPc}=$SipPc";
               mkpath($SipPc_dir) unless -d $SipPc_dir;

               for my $SipPcTermination (@{ $parameters{METADATA}{SipPcTermination} } ) {
                  print "\n            $SipPcTermination             = $SipPcTermination\n" if $debug;
                  my $SipPcTermination_dir = "$SipPc_dir/SipPcTermination$mo_suffix{SipPcTermination}=$SipPcTermination";
                  mkpath($SipPcTermination_dir) unless -d $SipPcTermination_dir;
               }
            }
         }
      }

      # ProcessorManagement MOs
      for my $ProcessorManagement (@{ $parameters{METADATA}{ProcessorManagement} } ) {
         print "\n            $ProcessorManagement             = $ProcessorManagement\n" if $debug;
         my $dir = "$node_dir/SbgFunction$mo_suffix{SbgFunction}=$SbgFunction/ProcessorManagement$mo_suffix{ProcessorManagement}=$ProcessorManagement";
         mkpath($dir) unless -d $dir;

         # MatedPair MOs 
         for my $MatedPair (@{ $parameters{METADATA}{MatedPair} } ) {
            print "\n            $MatedPair             = $MatedPair\n" if $debug;
            my $mated_pair_dir = "$dir/MatedPair$mo_suffix{MatedPair}=$MatedPair";
            mkpath($mated_pair_dir) unless -d $mated_pair_dir;

            # PayloadProcessor MOs 
            for my $PayloadProcessor (@{ $parameters{METADATA}{PayloadProcessor} } ) {
               print "\n            $PayloadProcessor             = $PayloadProcessor\n" if $debug;
               my $pp_dir = "$mated_pair_dir/PayloadProcessor$mo_suffix{PayloadProcessor}=$PayloadProcessor";
               mkpath($pp_dir) unless -d $pp_dir;
            }
         }
      }
   }

   # SGC MOs
   for my $SGC (@{ $parameters{METADATA}{SGC} } ) {
      print "            SGC             = $SGC\n" if $debug;

      # NetworkQoS MOs
      for my $NetworkQoS (@{ $parameters{METADATA}{NetworkQoS} } ) {
         print "\n            $NetworkQoS             = $NetworkQoS\n" if $debug;
         my $dir = "$node_dir/SGC$mo_suffix{SGC}=$SGC/NetworkQoS$mo_suffix{NetworkQoS}=$NetworkQoS";
         mkpath($dir) unless -d $dir;
      }
      
      # SgcBlade MOs
      for my $SgcBlade (@{ $parameters{METADATA}{SgcBlade} } ) {
         print "\n            $SgcBlade             = $SgcBlade\n" if $debug;
         my $dir = "$node_dir/SGC$mo_suffix{SGC}=$SGC/SgcBlade$mo_suffix{SgcBlade}=$SgcBlade";
         mkpath($dir) unless -d $dir;

         # SgcCp MOs 
         for my $SgcCp (@{ $parameters{METADATA}{SgcCp} } ) {
            print "\n            $SgcCp             = $SgcCp\n" if $debug;
            my $sgccp_dir = "$dir/SgcCp$mo_suffix{SgcCp}=$SgcCp";
            mkpath($sgccp_dir) unless -d $sgccp_dir;
         }
      }
      
      # SignalingNetworkConnection MOs
      for my $SignalingNetworkConnection (@{ $parameters{METADATA}{SignalingNetworkConnection} } ) {
         print "\n            $SignalingNetworkConnection             = $SignalingNetworkConnection\n" if $debug;
         my $dir = "$node_dir/SGC$mo_suffix{SGC}=$SGC/SignalingNetworkConnection$mo_suffix{SignalingNetworkConnection}=$SignalingNetworkConnection";
         mkpath($dir) unless -d $dir;

         # Sip MOs 
         for my $Sip (@{ $parameters{METADATA}{Sip} } ) {
            print "\n            $Sip             = $Sip\n" if $debug;
            my $sip_dir = "$dir/Sip$mo_suffix{Sip}=$Sip";
            mkpath($sip_dir) unless -d $sip_dir;
            # ProxyRegistrar MOs 
            for my $ProxyRegistrar (@{ $parameters{METADATA}{ProxyRegistrar} } ) {
               print "\n            $ProxyRegistrar             = $ProxyRegistrar\n" if $debug;
               my $pr_dir = "$sip_dir/ProxyRegistrar$mo_suffix{ProxyRegistrar}=$ProxyRegistrar";
               mkpath($pr_dir) unless -d $pr_dir;
            }
         }
         # SipV6 MOs 
         for my $SipV6 (@{ $parameters{METADATA}{SipV6} } ) {
            print "\n            $SipV6             = $SipV6\n" if $debug;
            my $sip_dir = "$dir/SipV6$mo_suffix{SipV6}=$SipV6";
            mkpath($sip_dir) unless -d $sip_dir;
            # ProxyRegistrarV6 MOs 
            for my $ProxyRegistrarV6 (@{ $parameters{METADATA}{ProxyRegistrarV6} } ) {
               print "\n            $ProxyRegistrarV6             = $ProxyRegistrarV6\n" if $debug;
               my $pr_dir = "$sip_dir/ProxyRegistrarV6$mo_suffix{ProxyRegistrarV6}=$ProxyRegistrarV6";
               mkpath($pr_dir) unless -d $pr_dir;
            }
         }
      }
   }
}

