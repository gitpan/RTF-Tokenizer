# RTF::Tokenizer - Peter Sergeant <rtft@clueball.com>

=head1 NAME

RTF::Tokenizer - Tokenize RTF

=head1 DESCRIPTION

Tokenizes RTF

=head1 SYNOPSIS

 use RTF::Tokenizer;
 
 # Create a tokenizer object
 my $tokenizer = RTF::Tokenizer->new();
 
 # Populate it from a file
 $tokenizer->read_file('filename.txt');
 
 # Or a file handle
 $tokenizer->read_file( \*STDIN );
 
 # Or a string
 $tokenizer->read_string( '{\*\some rtf}' );

 # Get the first token
 my ( $token_type, $argument, $parameter ) =
    $tokenizer->get_token();

=head1 INTRODUCTION

This documentation assumes some basic knowledge of RTF.
If you lack that, go read The_RTF_Cookbook:

http://search.cpan.org/search?dist=RTF-Writer

=cut

require 5;
package RTF::Tokenizer;
use vars qw($VERSION);

use strict;
use Carp;
use IO::File;

$VERSION = '1.00';

=head1 METHODS

=head2 new()

Returns a Tokenizer object. Currently accepts no arguments.

=cut

sub new {

	my $self = {};
	
	$self->{_BUFFER} = '';
	$self->{_FILEHANDLE} = '';
	
	$self->{_UC} = 1;
	
	bless $self;
	
	return $self;

}

=head2 read_string( STRING )

Fills the Tokenizer's buffer with the string, ready
to start tokenizing.

=cut

sub read_string {

	my $self = shift;
	$self->{_BUFFER} = shift;

}

=head2 read_file( \*FILEHANDLE )

=head2 read_file( filename )

Puts the first line from the filehandle into the buffer,
and remembers the filehandle, so if you ask for a token,
and the buffer is empty, it'll try and read the next line
from the file.

=cut

sub read_file {

	my $self = shift;
	my $file = shift;
	
	if (ref $file) {
	
		$self->{_FILEHANDLE} = IO::File->new_from_fd( $file, '<' );
		
	} else {
		
		$self->{_FILEHANDLE} = new IO::File "< $file";
		croak "Couldn't open $file for reading" unless $self->{_FILEHANDLE};
		
	}

	# Check what our line-endings seem to be, then set $/ accordingly.
	# (this code needs to be explicitly tested)
	_line_endings( $self );

	$self->{_BUFFER} .= $self->{_FILEHANDLE}->getline();

}

sub _line_endings {

	my $self = shift();

	$self->{_FILEHANDLE}->read( $self->{_BUFFER}, 500);
	
	# This should catch all cases
	if ( $self->{_BUFFER} =~ m/(\cM\cJ|\cM|\cJ)/ ) {
	
		$/ = $1;
		
	}
	
	$self->{_RS} = "Macintosh" if $/ eq "\cM";
	$self->{_RS} = "Windows" if $/ eq "\cM\cJ";
	$self->{_RS} = "UNIX" if $/ eq "\cJ";
}

=head2 get_token()

Returns the next token as a 3 item list: 'type', 'argument', 'parameter'.
Token is one of: text, control, group, or eof.

B<text>

'type' is set to 'text'. 'argument' is set to the text itself. 'parameter'
is left blank. NOTE: \{, \}, and \\ are all returned as control words,
rather than rendered as text for you. As with \_, \- and friends.

B<control>

'type' is 'control'. 'argument' is the control word or control symbol.
'parameter' is the control word's parameter if it has one - this will
be numeric, EXCEPT when 'argument' is a literal ', in which case it 
will be a two-letter hex string.

B<group>

'type' is 'group'. If it's the beginning of an RTF group, then
'argument' is 1, else if it's the end, argument is 0. 'parameter'
is not set.

B<eof>

End of file reached. 'type' is 'eof'. 'argument' is 1. 'parameter' is
0.

=cut

sub get_token {

	my $self = shift;

	while (1) {
	
		#print substr($self->{_BUFFER}, 0, 50) . "\n";
	
		my $start_character = substr( $self->{_BUFFER}, 0, 1, '' );
		
		# Most likely to be text, so we check for that first
		if ( $start_character =~ /[^\\}\r\n\t{]/ ) {
			
			local($^W); # Turn off warnings here
			$self->{_BUFFER} =~ s/^([^\{\}\\\n\r]+)//;
			return( 'text', $start_character . $1, '' );
		
		# Second most likely to be a control character
		} elsif ( $start_character eq "\\" ) {
			
			return( 'control', $self->_grab_control() );
		
		# Probably a group then	
		} elsif ( $start_character eq "{" ) {
		
			return( 'group', 1, '');
		
		} elsif ( $start_character eq "}" ) {
		
			return( 'group', 0, '');
			
		} elsif ( !$start_character ) {
		
			# We were read from a string, so return
			return( 'eof', 1, 0 ) unless $self->{_FILEHANDLE};
			
			# See if there's anything left to read
			local($^W); # Turn warnings off for this
			$self->{_BUFFER} .= $self->{_FILEHANDLE}->getline();
			return( 'eof', 1, 0 ) unless $self->{_BUFFER};
		
		}
	
	}

}

sub _grab_control {

	my $self = shift;
	
	# Some handler for \bin here, when I work it out
	
	if ( $self->{_BUFFER} =~ s/^\*// ) {
	
		return( '*','');
	
	# An honest-to-god standard control word:
	} elsif ( $self->{_BUFFER} =~ s/^([a-z]{1,32})((?:\d+|-\d+))?(?:[ ]|(?=[^a-z0-9]))//i ) {
	
			my $param = ''; $param = $2 if defined($2);
			return( $1, $param ) unless $1 eq 'bin';
			
			# Binary data or uc
			
	# hex-dec character
	} elsif ( $self->{_BUFFER} =~ s/^'([0-9abcdef][0-9abcdef])//i ) {
	
		return( "'", $1 );
	
	# Control symbol
	} elsif ( $self->{_BUFFER} =~ s/^([-_~:|{}*\'\\\\])// ) {
	
		return( $1, '' );
	
	# Unicode characters
	} elsif ( $self->{_BUFFER} =~ s/^u(\d+)// ) {
	
		return( 'u', $1 );
	
	}
	
	# Something is very fucked. Bail
	my $die_string =  substr( $self->{_BUFFER}, 0, 100 );
	$die_string =~ s/\r/[R]/g; 
	die ("Something went very wrong:\n$die_string\n" );

}

=head1 BUGS

To avoid intrusively deep parsing, if an alternative ASCII
representation is available for a unicode entity, and that
ASCII representation contains {, or \, by themselves, things
will go b<funky>. But I'm not convinced either of those are
allowed by the spec.

=head1 AUTHOR

Peter Sergeant E<lt>rtfr@clueball.comE<gt>

=head1 COPYRIGHT

Copyright 2003 Peter Sergeant.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut



1;
