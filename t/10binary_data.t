use strict;


use RTF::Tokenizer;
use Test::More tests => 11;


SKIP: {
	eval { require IO::Scalar };
	skip "IO::Scalar not installed", 11 if $@;

my $xstring = 'x' x 500;

my $stringMAC = "{\\rtf1 Hi there\cM$xstring\cMSee ya!\\bin6}}}}\n}abc\\la}\\bin5 ab";
my $fhMAC = new IO::Scalar \$stringMAC;

my $tokenizer = RTF::Tokenizer->new( file => $fhMAC );


ok( eq_array( [$tokenizer->get_token()], ['group', 1, ''] ), 'Groups opens' );
ok( eq_array( [$tokenizer->get_token()], ['control', 'rtf', 1] ), 'RTF v1' );
ok( eq_array([$tokenizer->get_token()],['text','Hi there',''] ), 'Read text' );
ok( eq_array([$tokenizer->get_token()],['text',$xstring,''] ), 'Read text' );
ok( eq_array([$tokenizer->get_token()],['text','See ya!',''] ), 'Read text' );
ok( eq_array( [$tokenizer->get_token()], ['control', 'bin', '6'] ), 'Read the binary control' );
ok( eq_array([$tokenizer->get_token()],['text',"}}}}\n}",''] ), 'Read binary data' );
#die( $tokenizer->{_BUFFER} );
ok( eq_array([$tokenizer->get_token()],['text','abc',''] ), 'Read text' ); 
ok( eq_array( [$tokenizer->get_token()], ['control', 'la', ''] ), 'Read control' );
ok( eq_array( [$tokenizer->get_token()], ['group', 0, ''] ), 'Groups closes' );

local $@ = undef;
eval '$tokenizer->get_token()';
my $error = $@;

like( $error, qr/^\\bin is asking for 5 characters, but there are only 2 left/, 'Too few characters causes error' );

}