use strict;
use Test::More tests => 5;
use RTF::Tokenizer;

my $tokenizer = RTF::Tokenizer->new();

isa_ok( $tokenizer, 'RTF::Tokenizer', 'new returned an RTF::Tokenizer object' );

# Test from a filename

$tokenizer->read_file('eg/test.rtf');
like( $tokenizer->{_BUFFER}, qr/^{\\rtf1\s*/, 'read_file from filename gets first line' );
is( $tokenizer->{_RS}, "UNIX", 'Line-endings identified as UNIX');

# Test from a filehandle

open(FALA, '< eg/test.rtf') || die $!;
$tokenizer->read_file(\*FALA);

like( $tokenizer->{_BUFFER}, qr/^{\\rtf1\s*/, 'read_file from filehandle gets first line' );
is( $tokenizer->{_RS}, "UNIX", 'Line-endings identified as UNIX');

