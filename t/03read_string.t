use strict;
use Test::More tests => 2;
use RTF::Tokenizer;

my $tokenizer = RTF::Tokenizer->new();

isa_ok( $tokenizer, 'RTF::Tokenizer', 'new returned an RTF::Tokenizer object' );

$tokenizer->read_string( "{\\rtf\n\\ansi}" );

is( $tokenizer->{_BUFFER}, "{\\rtf\n\\ansi}", 'Data transfered from string to buffer' );