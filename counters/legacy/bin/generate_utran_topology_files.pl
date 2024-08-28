#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Carp;

my @rncs  = ( 'rnc01' .. 'rnc10' );
my @cells = ( 'cell001' .. 'cell750' );    # each RNC has this list of cells, use '001'..'100' or '0001'..'1000' for a hundred or thousand respectively

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my $topology_dir      = "/eniq/data/pmdata/$oss_id/utran/topologyData";
my $rnc_topology_dir  = "$topology_dir/RNC";
my $site_topology_dir = "$topology_dir/Site";

create_pmdata_dirs( $rnc_topology_dir, $site_topology_dir );

create_site_topology_file( $root_mo, $site, $site_topology_dir, $timezone );

my %cell_ids_for;
my %local_cell_id_for;
my $local_cell_id = 1;    # ensure that each cell has a unique local cell ID, this is the start value

for my $rnc_id (@rncs) {
    my @cell_ids;
    for my $cell (@cells) {
        my $cell_id = "${rnc_id}$cell";
        push @cell_ids, $cell_id;
        $local_cell_id_for{$cell_id} = $local_cell_id;
        $local_cell_id++;    # ensure unique local cell ID
    }
    $cell_ids_for{$rnc_id} = \@cell_ids;    # save an array ref to cell IDs
}

my @mo_types = qw(Rnc UtranCell);

for my $rnc_id (@rncs) {

    my $rnc_fdn       = "$root_mo,SubNetwork=$rnc_id,MeContext=$rnc_id";
    my $topology_file = "$rnc_topology_dir/SubNetwork_${rnc_id}_MeContext_${rnc_id}.xml";

    open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
    print {$TOPOLOGY_FH} topology_header(), "\n";

    for my $mo_type (@mo_types) {
        if ( $mo_type eq 'Rnc' ) {
            print {$TOPOLOGY_FH} rnc_topology( $root_mo, $rnc_fdn, $rnc_id, $site );
        }
        elsif ( $mo_type eq 'UtranCell' ) {
            for my $cell_id ( @{ $cell_ids_for{$rnc_id} } ) {
                my $moid = "ManagedElement=1,RncFunction=1,UtranCell=$cell_id";
                print {$TOPOLOGY_FH} utrancell_topology( $moid, $cell_id, $local_cell_id_for{$cell_id} );
            }
        }
    }
    print {$TOPOLOGY_FH} topology_footer(), "\n";
    close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
}

sub rnc_topology {
    my ( $root_mo, $rnc_fdn, $rnc_id, $site ) = @_;
    return <<"RNC_TOPOLOGY";
   <mo fdn="$rnc_fdn" mimName="RNC_NODE_MODEL" mimVersion="G.5.16.F.5.2">
      <attr name="userLabel">$rnc_id</attr>
      <attr name="MeContextId">$rnc_id</attr>
      <attr name="neMIMversion">vG.5.16</attr>
      <attr name="rbsIubId"></attr>
   </mo>

   <mo fdn="$rnc_fdn,ManagedElement=1">
      <attr name="siteRef">$root_mo,Site=$site</attr>
   </mo>

RNC_TOPOLOGY
}

sub utrancell_topology {
    my ( $cell_fdn, $cell_id, $local_cell_id ) = @_;

    return <<"CELL_TOPOLOGY";
   <mo fdn="$cell_fdn">
      <attr name="userLabel">$cell_id</attr>
      <attr name="UtranCellId">$cell_id</attr>
      <attr name="local_cell_id">$local_cell_id</attr>
      <attr name="tCell">1</attr>
   </mo>

CELL_TOPOLOGY
}

__END__

$Author: eeikcoy $

$Date: 2007-09-06 13:46:46 +0100 (Thu, 06 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_utran_topology_files.pl $

$Id: generate_utran_topology_files.pl 49 2007-09-06 12:46:46Z eeikcoy $


=head1 NAME

generate_utran_topology_files - creates the ENIQ topology directories and files for RNC nodes.

=head1 VERSION

This documentation refers to generate_utran_topology_files.pl version 1.0. 

=head1 USAGE

No arguments required, just run using the command:

=over 

=item    generate_utran_topology_files.pl

=back

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

None

=head1 DESCRIPTION

This script creates all the topology information needed for the ENIQ RNC nodes.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/utran

=item * /eniq/data/pmdata/eniq_oss_1/utran/topologyData

=item * /eniq/data/pmdata/eniq_oss_1/utran/topologyData/RNC

=item * /eniq/data/pmdata/eniq_oss_1/utran/topologyData/Site

=back

=head2 RNC

The RNC topology files are stored in the RNC directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/utran/topologyData/RNC/SubNetwork_rnc01_MeContext_rnc01.xml

=back


=head2 Site

The Site topology files are stored in the Site directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/utran/topologyData/Site/sites.xml

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

