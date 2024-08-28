#!/usr/bin/perl
use strict;
use warnings;
use lib '/eniq/home/dcuser/counters/lib';
use Encoding::BER;

use Data::Dumper;
my $enc = Encoding::BER->new();

my $asn1_file = $ARGV[0];

open(ASN, "< :raw", $asn1_file) or die "can't open $asn1_file: $!";

my $buff;
my $bytes = read(ASN, $buff, 2**10 * 500);
my $data = $enc->decode( $buff );

for my $key (keys %{ $data } ) {
   print "$key -> $data->{$key}\n";
}


print "type -> $data->{type}[0]\n";
print "type -> $data->{type}[1]\n";

for my $text ($data->{type}) {
   print "$text->[0]\n";
}

print Dumper($data);

