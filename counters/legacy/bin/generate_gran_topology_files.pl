#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use ENIQ::Reports;
use Carp;

my @bscs  = ( 'bsc01' .. 'bsc20' );
my @cells = ( 'cell001' .. 'cell750' );

my ( $timezone, $oss_id, $site, $root_mo ) = get_config_data();

my $site_FDN         = "$root_mo,Site=$site";
my $topology_basedir = "/eniq/data/pmdata/$oss_id/gran/topologyData";

my %topology_dir_for = (
    Site => 'Site',
    BSC  => 'GranNetwork',
    CELL => 'CELL',
    AREA => 'DIM_BSS_AREA',
);

my %fields_for = (
    Site    => 'siteFDN|siteName|timeZone',
    BSC     => 'nodeFDN|userLabel|nodeVersion|nodeType|sourceType|TRX|siteFDN',
    CELL    => 'cellName|bscName|siteName|cellType|cellBand|cellLayer',
    AREA    => 'AREA,AREA_GROUP,OSS_ID,CELL_ID,CELL_NAME,NW_TYPE',
    SiteDST => 'fdn;userLabel;SiteId;DST',
);

my %timezone_for = (
    Athlone    => 'UTC+00:00',
    Dublin     => 'UTC+00:00',
    Paris      => 'UTC+01:00',
    'New York' => 'UTC-05:00',
);

create_pmdata_dirs("$topology_basedir/$_") for values %topology_dir_for;

my $site_data = "$fields_for{Site}\n";
for my $site ( sort keys %timezone_for ) {
    $site_data .= "$root_mo,Site=$site|$site|$timezone_for{$site}\n";
}
create_topology_file( "$topology_basedir/$topology_dir_for{Site}/Site", "$site_data" );

my $bsc_data      = "$fields_for{BSC}\n";
my $cell_data     = "$fields_for{CELL}\n";
my $area_data     = "$fields_for{AREA}\n";
my $site_DST_data = "$fields_for{SiteDST}\n";

my $node_version = '06B';
my $node_type    = 'BSC';
my $source_type  = 'AXE';
my $TRX          = '100';

my $cell_type  = '0';
my $cell_band  = '900';
my $cell_layer = '1';

for my $bsc_name (@bscs) {
    my $node_FDN   = "$root_mo,SubNetwork=gran1,ManagedElement=$bsc_name";
    my $user_label = $bsc_name;
    $bsc_data .= "$node_FDN|$user_label|$node_version|$node_type|$source_type|$TRX|$site_FDN\n";

    for my $cell_name (@cells) {
        $cell_data .= "$bsc_name$cell_name|$bsc_name|$site|$cell_type|$cell_band|$cell_layer\n";
    }
}

create_topology_file( "$topology_basedir/$topology_dir_for{BSC}/BSC", "$bsc_data" );

create_topology_file( "$topology_basedir/$topology_dir_for{CELL}/CELL", "$cell_data" );

my %area_for = (
    bsc01 => 'Athlone',
    bsc02 => 'Dublin',
);

my @area_cells = ( 'cell001' .. 'cell010' );

for my $bsc_name ( sort keys %area_for ) {
    for my $cell_name (@area_cells) {
        my ($cell_id) = $cell_name =~ m/(\d+)$/mx;    # last digits are cell ID
        $area_data .= "$area_for{$bsc_name},Cell Set,$oss_id,$cell_id,$bsc_name$cell_name,AXE\n";
    }
}

create_topology_file( "$topology_basedir/$topology_dir_for{AREA}/DIM_BSS_AREA", "$area_data" );

my %site_DST_for = (
    'Athlone' => 1,
    'Dublin'  => 1,
);

for my $site_dst ( sort keys %site_DST_for ) {
    $site_DST_data .= "$root_mo,Site=$site_dst;$site_dst;$site_dst;$site_DST_for{$site_dst}\n";
}

mkdir "/eniq/data/pmdata/$oss_id/SiteDSTGRAN";
create_topology_file( "/eniq/data/pmdata/$oss_id/SiteDSTGRAN/DIM_E_GRAN_SITEDST.txt", "$site_DST_data" );

sub create_topology_file {
    my ( $topology_file, $topology_data ) = @_;

    open my $TOPOLOGY_FH, '>', $topology_file or croak "Cannot open file $topology_file, $!";
    print {$TOPOLOGY_FH} "$topology_data";
    close $TOPOLOGY_FH or croak "Cannot close file $topology_file, $!";
    return;
}

__END__

$Author: eeikcoy $

$Date: 2007-09-06 13:46:46 +0100 (Thu, 06 Sep 2007) $

$HeadURL: file:///cygdrive/c/svn/counters/bin/generate_gran_topology_files.pl $

$Id: generate_gran_topology_files.pl 49 2007-09-06 12:46:46Z eeikcoy $


=head1 NAME

generate_gran_topology_files - creates the ENIQ topology directories and files for BSC nodes.

=head1 VERSION

This documentation refers to generate_gran_topology_files.pl version 1.0. 

=head1 USAGE

No arguments required, just run using the command:

=over 

=item    generate_gran_topology_files.pl

=back

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

None

=head1 DESCRIPTION

This script creates all the topology information needed for the ENIQ GRAN nodes.

For the specification of the contents of the topology files, see "Interwork Description for ENIQ-M xml files",
1/15519-APR 901 0199.

=head2 Directories

The topology directories created are:

=over

=item * /eniq/data/pmdata/eniq_oss_1/gran

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/CELL

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/DIM_BSS_AREA

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/GranNetwork

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/Site

=back

=head2 CELL

The Cell topology files are stored in the CELL directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/CELL/CELL

=back


=head2 CELL SET

The Cell Set topology files are stored in the DIM_BSS_AREA directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/DIM_BSS_AREA/DIM_BSS_AREA

=back

=head2 BSC

The BSC topology files are stored in the BSC directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/GranNetwork/BSC

=back

=head2 Site

The Site topology files are stored in the Site directory, an example file is:

=over

=item * /eniq/data/pmdata/eniq_oss_1/gran/topologyData/Site/Site

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

