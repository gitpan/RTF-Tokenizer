#/usr/bin/perl

use RTF::Tokenizer;
use strict;

my $filename = $ARGV[0];

open(RTF, "< $filename")||die $!;
my $file = join '', <RTF>;
close RTF;

my $object = RTF::Tokenizer->new($file);

while (1) {
  my ($type, $value, $extra) = $object->get_token;
  print "$type, $value, $extra\n";
  if ($type eq 'eof') { exit; }
}