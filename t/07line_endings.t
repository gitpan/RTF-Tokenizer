use strict;
use Test::More tests => 15;
use RTF::Tokenizer;
use IO::Scalar;

my $tokenizer = RTF::Tokenizer->new();

my $stringMAC = "{\\rtf1 Hi there\cM}";
my $stringNIX = "{\\rtf1 Lo there\cJ}";
my $stringWIN = "{\\rtf1 Ho there\cM\cJ}";

my $fhMAC = new IO::Scalar \$stringMAC;
my $fhNIX = new IO::Scalar \$stringNIX;
my $fhWIN = new IO::Scalar \$stringWIN;

$tokenizer->{_FILEHANDLE} = $fhMAC;
$tokenizer->{_BUFFER} = '';
$tokenizer->_line_endings;
is( $tokenizer->{_RS}, 'Macintosh', 'Mac endings read right');
ok( eq_array( [$tokenizer->get_token()], ['group', 1, ''] ), 'Groups opens' );
ok( eq_array( [$tokenizer->get_token()], ['control', 'rtf', 1] ), 'RTF v1' );
ok( eq_array([$tokenizer->get_token()],['text','Hi there',''] ), 'Read text' );
ok( eq_array( [$tokenizer->get_token()], ['group', 0, ''] ), 'Groups closes' );

$tokenizer->{_FILEHANDLE} = $fhNIX;
$tokenizer->{_BUFFER} = '';
$tokenizer->_line_endings;
is( $tokenizer->{_RS}, 'UNIX', 'UNIX endings read right');
ok( eq_array( [$tokenizer->get_token()], ['group', 1, ''] ), 'Groups opens' );
ok( eq_array( [$tokenizer->get_token()], ['control', 'rtf', 1] ), 'RTF v1' );
ok( eq_array([$tokenizer->get_token()],['text','Lo there',''] ), 'Read text' );
ok( eq_array( [$tokenizer->get_token()], ['group', 0, ''] ), 'Groups closes' );

$tokenizer->{_FILEHANDLE} = $fhWIN;
$tokenizer->{_BUFFER} = '';
$tokenizer->_line_endings;
is( $tokenizer->{_RS}, 'Windows', 'Windows endings read right');
ok( eq_array( [$tokenizer->get_token()], ['group', 1, ''] ), 'Groups opens' );
ok( eq_array( [$tokenizer->get_token()], ['control', 'rtf', 1] ), 'RTF v1' );
ok( eq_array([$tokenizer->get_token()],['text','Ho there',''] ), 'Read text' );
ok( eq_array( [$tokenizer->get_token()], ['group', 0, ''] ), 'Groups closes' );

