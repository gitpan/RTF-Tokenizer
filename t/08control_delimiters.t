use strict;
use Test::More tests => 7;
use RTF::Tokenizer;

my $tokenizer = RTF::Tokenizer->new();

# These are tests to check that control-word delimiters are handled 
# as the specification says, as I've screwed this up once, and 
# chromatic says add tests for bugs you find, to stop them creeping
# back in.

$tokenizer->read_string(q?\rtf1 Pete\'acPete\u45Pete?);

ok( eq_array( [$tokenizer->get_token()], ['control', 'rtf', 1] ), '\rtf1 read correctly' );
ok( eq_array( [$tokenizer->get_token()], ['text', 'Pete', ''] ), 'Read text "Pete" correctly' );
ok( eq_array( [$tokenizer->get_token()], ['control', "'", 'ac'] ), 'Read entity' );
ok( eq_array( [$tokenizer->get_token()], ['text', 'Pete', ''] ), '"Pete" read, which means entity delimiter used' );
ok( eq_array( [$tokenizer->get_token()], ['control', 'u', '45'] ), 'u Control read, which means special u delim rules used' );
ok( eq_array( [$tokenizer->get_token()], ['text', 'Pete', ''] ), '"Pete" read, which means entity delimiter used' );

$tokenizer->read_string(q?\rtf1a?);

# This should die

local $@ = undef;
eval '$tokenizer->get_token()';
my $error_message = $@; $error_message =~ s/\n//g;
ok( $@, "\\rtf1a caused fatal error: '$error_message'");

