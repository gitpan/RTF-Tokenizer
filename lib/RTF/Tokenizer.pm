# RTF::Tokenizer - Peter Sergeant <rtft@clueball.com>

=head1 NAME

RTF::Tokenizer - Tokenize RTF

=head1 DESCRIPTION

Tokenizes RTF

=head1 SYNOPSIS

 use RTF::Tokenizer;
 
 # Create a tokenizer object
 my $tokenizer = RTF::Tokenizer->new();
 my $tokenizer = RTF::Tokenizer->new( string => '{\rtf1}'  );
 my $tokenizer = RTF::Tokenizer->new( file   => \*STDIN    );
 my $tokenizer = RTF::Tokenizer->new( file   => 'lala.rtf' );
 
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

L<http://search.cpan.org/search?dist=RTF-Writer>

=cut

# TODO:
#	- Remove the need for IO::Scalar, and Test::More (CHANGES)
#	- Update MANIFEST

require 5;
package RTF::Tokenizer;
use vars qw($VERSION);

use strict;
use Carp;
use IO::File;

$VERSION = '1.01';

=head1 METHODS

=head2 new( )

Returns a Tokenizer object. Normally called with no arguments,
however, you can save yourself calling C<read_file()> or C<read_string()>
by passing C<new()> a hash (well, a list really) containing either
a 'file'- or 'string'-indexed couplet, where the value is what
you would like passed to the respective routine. The example in
the synopsis makes this much more clear than does this description :-)

=cut

sub new {

	# Get the real class name
	my $proto = shift;
	my $class = ref( $proto ) || $proto;
	
	my $self = {};
	
	$self->{_BUFFER} = '';
	$self->{_BINARY_DATA} = '';
	$self->{_FILEHANDLE} = '';
	$self->{_INITIAL_READ} = 512;
	
	# Default number of characters to count for \uc
	$self->{_UC} = 1;
	
	bless $self, $class;
	
	# Do we do some initialization too?
	my %config = @_;
	if ( $config{'file'} ) { $self->read_file( $config{'file'} ) }
	elsif ( $config{'string'} ) { $self->read_string( $config{'string'} ) }
	
	# Return our newly blessed
	return $self;

}

=head2 read_string( STRING )

Appends the string to the tokenizer-object's buffer
(earlier versions would over-write the buffer -
this version does not).

=cut

sub read_string {

	my $self = shift;
	$self->{_BUFFER} .= shift;

}

=head2 read_file( \*FILEHANDLE )

=head2 read_file( $IO_File_object )

=head2 read_file( 'filename' )

Appends a chunk of data from the filehandle to the buffer,
and remembers the filehandle, so if you ask for a token,
and the buffer is empty, it'll try and read the next line
from the file (earlier versions would over-write the buffer -
this version does not).

This chunk is 500 characters, and then whatever is left until
the next occurrence of the IRS (a newline character in this case).
If for whatever reason, you want to change that number to something
else, $self->{_INITIAL_READ} can be modified.

=cut

sub read_file {

	my $self = shift;
	my $file = shift;
	
	if (ref $file eq 'GLOB') {
	
		$self->{_FILEHANDLE} = IO::File->new_from_fd( $file, '<' );
		croak "Couldn't create an IO::File object from the reference you specified" unless $self->{_FILEHANDLE};
	
	} elsif (ref $file eq 'IO::File') {
	
		$self->{_FILEHANDLE} = $file;
		croak "Something unpossible happened (and your printer is probably on fire)" unless $self->{_FILEHANDLE};
		
	# This is undocumented, because you shouldn't use it. Don't rely on it.
	} elsif (ref $file eq 'IO::Scalar') {
	
		$self->{_FILEHANDLE} = $file;
		croak "Something unpossible happened (and your printer is probably on fire)" unless $self->{_FILEHANDLE};

	} elsif ( !ref $file ) {
		
		$self->{_FILEHANDLE} = IO::File->new( "< $file" );
		croak "Couldn't open $file for reading" unless $self->{_FILEHANDLE};
		
	} else {
	
		croak "You passed a reference to read_file of type ". ref($file) . " which isn't an allowed type";
	
	}

	# Check what our line-endings seem to be, then set $self->{_IRS} accordingly.
	# This also reads in the first few lines as a side effect.
	$self->_line_endings;

}

sub _get_line {

	my $self = shift();

	# Do some localized cleverness
	local($^W); # Turn warnings off for this
	local $/ = $self->{_IRS};

	# Read the line itself
	$self->{_BUFFER} .= $self->{_FILEHANDLE}->getline();

}

sub _line_endings {

	my $self = shift();

	my $temp_buffer;
	
	$self->{_FILEHANDLE}->read( $temp_buffer, $self->{_INITIAL_READ});
	
	# This should catch all cases
	if ( $temp_buffer =~ m/(\cM\cJ|\cM|\cJ)/ ) {
	
		$self->{_IRS} = $1;
		
	}
	
	$self->{_RS} = "Macintosh" if $self->{_IRS} eq "\cM";
	$self->{_RS} = "Windows" if $self->{_IRS} eq "\cM\cJ";
	$self->{_RS} = "UNIX" if $self->{_IRS} eq "\cJ";
	
	# Add back to main buffer
	$self->{_BUFFER} .= $temp_buffer;
	
	# Make sure we're being sane about not only reading half a line
	$self->_get_line;
}

=head2 get_token()

Returns the next token as a three-item list: 'type', 'argument', 'parameter'.
Token is one of: C<text>, C<control>, C<group>, or C<eof>.

=over

=item C<text>

'type' is set to 'text'. 'argument' is set to the text itself. 'parameter'
is left blank. NOTE: C<\{>, C<\}>, and C<\\> are all returned as control words,
rather than rendered as text for you, as are C<\_>, C<\-> and friends.

=item C<control>

'type' is 'control'. 'argument' is the control word or control symbol.
'parameter' is the control word's parameter if it has one - this will
be numeric, EXCEPT when 'argument' is a literal ', in which case it 
will be a two-letter hex string.

=item C<group>

'type' is 'group'. If it's the beginning of an RTF group, then
'argument' is 1, else if it's the end, argument is 0. 'parameter'
is not set.

=item C<eof>

End of file reached. 'type' is 'eof'. 'argument' is 1. 'parameter' is
0.

=back

=cut

sub get_token {

	my $self = shift;

	if ( $self->{_BINARY_DATA} ) {
		
		my $data = $self->{_BINARY_DATA};
		$self->{_BINARY_DATA} = '';
		return('text', $data, '');	
		
	}

	while (1) {
	
		#print substr($self->{_BUFFER}, 0, 50) . "\n";
	
		my $start_character = substr( $self->{_BUFFER}, 0, 1, '' );
		
		# Most likely to be text, so we check for that first
		if ( $start_character =~ /[^\\{}\r\n\t]/ ) {
			
			local($^W); # Turn off warnings here
			$self->{_BUFFER} =~ s/^([^\\{}\r\n]+)//;
			return( 'text', $start_character . $1, '' );
		
		# Second most likely to be a control character
		} elsif ( $start_character eq "\\" ) {
			
			return( 'control', $self->_grab_control() );
		
		# Probably a group then	
		} elsif ( $start_character eq '{' ) {
		
			return( 'group', 1, '');
		
		} elsif ( $start_character eq '}' ) {
		
			return( 'group', 0, '');
			
		} elsif ( !$start_character ) {
		
			# We were read from a string, so return
			return( 'eof', 1, 0 ) unless $self->{_FILEHANDLE};
			
			# See if there's anything left to read
			$self->_get_line;
			return( 'eof', 1, 0 ) unless $self->{_BUFFER};
		
		}
	
	}

}

=head2 initial_read( [number] )

Don't call this unless you actually have a good reason. When
the Tokenizer reads from a file, it first attempts to work out
what the correct input record-seperator should be, by reading
some characters from the file handle. This value starts off
as 512, which is twice the amount of characters that version 1.7
of the RTF specification says you should go before including a
line feed if you're writing RTF.

Called with no argument, this returns the current value of the
number of characters we're going to read. Called with a numeric
argument, it sets the number of characters we'll read.

You really don't need to use this method.

=cut

sub initial_read {

	my $self = shift;
	
	if (@_) { $self->{_INITIAL_READ} = shift }
    
    return $self->{_INITIAL_READ};

}

sub _grab_control {

	my $self = shift;
	
	# Some handler for \bin here, when I work it out
	
	if ( $self->{_BUFFER} =~ s/^\*// ) {
	
		return( '*','');
	
	# An honest-to-god standard control word:
	} elsif ( $self->{_BUFFER} =~ s/^([a-z]{1,32})(-?\d+)?(?:[ ]|(?=[^a-z0-9]))//i ) {
	
			my $param = ''; $param = $2 if defined($2);
			return( $1, $param ) unless $1 eq 'bin';
			
			# Binary data
			$self->_grab_bin( $2 );
			return( 'bin', $2 );
			
	# hex-dec character
	} elsif ( $self->{_BUFFER} =~ s/^'([0-9a-f]{2})//i ) {
	
		return( "'", $1 );
	
	# Control symbol
	} elsif ( $self->{_BUFFER} =~ s/^([-_~:|{}*'\\])// ) {
	
		return( $1, '' );

	# Escaped whitespace (ew, but allowed)
	} elsif ( $self->{_BUFFER} =~ s/^[\r\n]// ) {
	
		return( 'par', '' );
	
	# Unicode characters
	} elsif ( $self->{_BUFFER} =~ s/^u(\d+)// ) {
	
		return( 'u', $1 );
		
	}
	
	# Something is very messed up. Bail
	my $die_string =  substr( $self->{_BUFFER}, 0, 100 );
	$die_string =~ s/\r/[R]/g; 
	croak "Something went very wrong:\n$die_string\n";

}

# A first stab at grabbing binary data
sub _grab_bin {

	my $self = shift;
	
	my $bytes = shift;
	
	while ( length( $self->{_BUFFER} ) < $bytes  ) {
		
		# Are we at the end?
		croak "\\bin is asking for $bytes characters, but there are only " . length( $self->{_BUFFER} ) . " left."
			if $self->{_FILEHANDLE}->eof;
		
		$self->_get_line;
	
	}
	
	# Return the right number of characters
	$self->{_BINARY_DATA} = substr( $self->{_BUFFER}, 0, $bytes, '' );

}

=head1 BUGS

To avoid intrusively deep parsing, if an alternative ASCII
representation is available for a Unicode entity, and that
ASCII representation contains C<{>, or C<\>, by themselves, things
will go B<funky>. But I'm not convinced either of those is
allowed by the spec.

=head1 AUTHOR

Pete Sergeant -- C<rtfr@clueball.com>

=head1 COPYRIGHT

Copyright 2003 B<Pete Sergeant>.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut



1;
