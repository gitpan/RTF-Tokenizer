#!/usr/bin/perl

 use strict;
 use RTF::Tokenizer;

 my $tokenizer = RTF::Tokenizer->new();
 $tokenizer->read_file( $ARGV[0] );

 while (1) {

     my ( $type, $argument, $param ) = 
	$tokenizer->get_token();
     
     last if $type eq 'eof';

     print $argument if $type eq 'text';
     print "\\$argument$param\n" if $type eq 'control';
     print '}' if ($type eq 'group') and !$argument;
     print '{' if ($type eq 'group') and $argument;

 }
