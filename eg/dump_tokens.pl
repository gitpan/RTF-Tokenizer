#/usr/bin/perl

use RTF::Tokenizer;
use strict;
use Benchmark;

my $t0 = new Benchmark;

my $filename = $ARGV[0];

my $tokenizer = RTF::Tokenizer->new();
$tokenizer->read_file( $filename );

while (1) {

	my ($type, $arg, $xtra) = $tokenizer->get_token();
	last if $type eq 'eof';

	print "['$type', '$arg', '$xtra'],\n";
}

my $t1 = new Benchmark;

my $td = timediff($t1, $t0);
print STDERR "the code took:",timestr($td),"\n";
