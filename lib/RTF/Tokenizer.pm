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
 
 my $tokenizer = RTF::Tokenizer->new( string => '{\rtf1}', note_escapes => 1 );
 
 # Populate it from a file
 $tokenizer->read_file('filename.txt');
 
 # Or a file handle
 $tokenizer->read_file( \*STDIN );
 
 # Or a string
 $tokenizer->read_string( '{\*\some rtf}' );

 # Get the first token
 my ( $token_type, $argument, $parameter ) =
    $tokenizer->get_token();

 # Ooops, that was wrong...
 $tokenizer->put_token( 'control', 'b', 1 );

=head1 INTRODUCTION

This documentation assumes some basic knowledge of RTF.
If you lack that, go read The_RTF_Cookbook:

L<http://search.cpan.org/search?dist=RTF-Writer>

=cut

require 5;
package RTF::Tokenizer;
use vars qw($VERSION);

use strict;
use Carp;
use IO::File;

$VERSION = '1.06';

=head1 METHODS

=head2 new( )

Returns a Tokenizer object. Normally called with no arguments,
however, you can save yourself calling C<read_file()> or C<read_string()>
by passing C<new()> a hash (well, a list really) containing either
a 'file'- or 'string'-indexed couplet, where the value is what
you would like passed to the respective routine. The example in
the synopsis makes this much more clear than does this description :-)

As of version 1.04, we can also differentiate between control words
and escapes. If you pass a C<note_escapes> parameter with a true value
then escapes will have a token type of C<escape> rather than C<control>.

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
	
	$self->{_NOTE_ESCAPES} = $config{'note_escapes'};
	
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
Token is one of: C<text>, C<control>, C<group>, C<escape> or C<eof>.

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

=item C<escape>

If you specifically turn on this functionality, you'll get an
C<escape> type, which is identical to C<control>, only, it's
only returned for escapes.

=back

=cut

sub get_token {

	my $self = shift;

	if ( $self->{_BINARY_DATA} ) {
		
		my $data = $self->{_BINARY_DATA};
		$self->{_BINARY_DATA} = '';
		return('text', $data, '');	
		
	}

	# We might have a cached token...
	if ( $self->{_PUT_TOKEN_CACHE_FLAG} ) {
		
		$self->{_PUT_TOKEN_CACHE_FLAG} = @{ $self->{_PUT_TOKEN_CACHE} } - 1;
		$self->{_PUT_TOKEN_CACHE_FLAG} = 0 if $self->{_PUT_TOKEN_CACHE_FLAG} < 1;
		return @{ pop( @{ $self->{_PUT_TOKEN_CACHE} } ) };

	}

	while (1) {
	
		#print substr($self->{_BUFFER}, 0, 50) . "\n";
	
		my $start_character = substr( $self->{_BUFFER}, 0, 1, '' );
		
		# Most likely to be text, so we check for that first
		if ( $start_character =~ /[^\\{}\r\n]/ ) {
			
			local($^W); # Turn off warnings here
			
			# Originally we just split text fields that wrapped
			#  newlines into two tokens. Now we're going to try
			#  and be clever, and read the whole thing in...
			
			my $temp_text;
			
			READTEXT:
			
			$self->{_BUFFER} =~ s/^([^\\{}]+)//s;
			
			$temp_text .= $1;
			
			# If the buffer is empty, try reading in some more, and
			#  then go back to READTEXT to keep going. Now, the clever
			#  thing would be to assume that if the buffer *IS* empty
			#  then there MUST be more to read, which is true if we
			#  have well-formed input. Assuming well-formed input is t3h
			#  stupid though.
			
			if ( ( !$self->{_BUFFER} ) && ( $self->{_FILEHANDLE} ) ) {
			
				$self->_get_line;
				goto READTEXT if $self->{_BUFFER};
			
			}
			
			# Make sure we're not including newlines in our output
			$temp_text =~ s/(\cM\cJ|\cM|\cJ)//g;
			
			return( 'text', $start_character . $temp_text, '' );
		
		# Second most likely to be a control character
		} elsif ( $start_character eq "\\" ) {
			
			my @args = $self->_grab_control();
			
			if ( $self->{_TEMP_ESCAPE_FLAG} ) {
			
				delete $self->{_TEMP_ESCAPE_FLAG};
				return( 'escape', @args );
			
			} else {
			
				return( 'control', @args );
			
			}
		
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

=head2 put_token( type, token, argument )

Adds an item to the token cache, so that the next time you
call get_token, the arguments you passed here will be returned.
We don't check any of the values, so use this carefully. This
is on a first in last out basis.

=cut

sub put_token {

	my $self = shift;
	my ( $type, $token, $argument ) = (shift, shift, shift);

	push( @{$self->{_PUT_TOKEN_CACHE}}, [ $type, $token, $argument ] ); 
	$self->{_PUT_TOKEN_CACHE_FLAG} = 1;

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

=head2 debug( [number] )

Returns (non-destructively) the next 50 characters from the buffer,
OR, the number of characters you specify. Printing these to STDERR,
causing fatal errors, and the like, are left as an exercise to the
programmer.

Note the part about 'from the buffer'. It really means that, which means
if there's nothing in the buffer, but still stuff we're reading from a
file it won't be shown. Chances are, if you're using this function, you're
debugging. There's an internal method called C<_get_line>, which is called
without arguments (C<$self->_get_line()>) that's how we get more stuff into
the buffer when we're reading from filehandles. There's no guarentee that'll
stay, or will always work that way, but, if you're debugging, that shouldn't
matter.

=cut

sub debug {

	my $self = shift;
	my $number = shift || 50;
	
	return substr( $self->{_BUFFER}, 0, $number );

}


sub _grab_control {

	my $self = shift;
	
	if ( $self->{_BUFFER} =~ s/^\*// ) {
	
		return( '*','');
	
	# An honest-to-god standard control word:
	} elsif ( $self->{_BUFFER} =~ s/^([a-z]{1,32})(-?\d+)?(?:[ ]|(?=[^a-z0-9]))//i ) {
	
			my $param = ''; $param = $2 if defined($2);
			return( $1, $param ) unless $1 eq 'bin';
			
			# Binary data
			$self->_grab_bin( $2 );
			return( 'bin', $2 );
			
	# hex-dec character (escape)
	} elsif ( $self->{_BUFFER} =~ s/^'([0-9a-f]{2})//i ) {
	
		$self->{_TEMP_ESCAPE_FLAG}++ if $self->{_NOTE_ESCAPES};
		return( "'", $1 );
	
	# Control symbol (escape)
	} elsif ( $self->{_BUFFER} =~ s/^([-_~:|{}*'\\])// ) {
	
		$self->{_TEMP_ESCAPE_FLAG}++ if $self->{_NOTE_ESCAPES};
		return( $1, '' );

	# Escaped whitespace (ew, but allowed)
	} elsif ( $self->{_BUFFER} =~ s/^[\r\n]// ) {
	
		return( 'par', '' );

	# Escaped tab (ew, but allowed)
	} elsif ( $self->{_BUFFER} =~ s/^\t// ) {
	
		return( 'tab', '' );

	# Escaped semi-colon - this is WRONG
	} elsif ( $self->{_BUFFER} =~ s/^\;// ) {
	
		carp("Your RTF contains an escaped semi-colon. This is *seriously* suboptimal.");
		return( ';', '' );
	
	# Unicode characters
	} elsif ( $self->{_BUFFER} =~ s/^u(\d+)// ) {
	
		return( 'u', $1 );
		
	}
	
	# Something is very messed up. Bail
	my $die_string =  substr( $self->{_BUFFER}, 0, 50 );
	$die_string =~ s/\r/[R]/g; 
	carp "Your RTF is broken, trying to recover to nearest group from '\\$die_string'\n";
	$self->{_BUFFER} =~ s/^.+?([}{])/$1/;
	return ( '', '');

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

=head1 NOTES

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
