
use strict;
use Test::More tests => 1;
use RTF::Tokenizer;

my $tokenizer = RTF::Tokenizer->new();

isa_ok( $tokenizer, 'RTF::Tokenizer', 'new returned an RTF::Tokenizer object' );