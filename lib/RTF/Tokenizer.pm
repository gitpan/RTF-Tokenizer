# RTF::Tokenizer 0.02.1

# by Peter Sergeant <pete@clueball.com>

# Magic Package Stuff

require 5;
package RTF::Tokenizer;
use vars qw($VERSION);
use strict;
our $VERSION = '0.02.1';

# Sample:
#
# my $object = RTF::Tokenizer->new($line, sub {return chr(hex($_[0]))});
# ...
# my ($type, $value, $extra) = $object->get_token;
# ...


sub new {

	my $self  = {};

	$self->{_BUFFER} = reverse $_[1]; # Store our buffer (we can only go one way to start with)
	$self->{_TOKEN} = '';
	$self->{_ARGUMENT} = '';
	$self->{_CACHE} = '';
	$self->{_STATE} = '';

	$self->{_BOOKMARKS} = {};

	# Supply a default entity handler
	$self->{_entity_conversion} = sub {return chr(hex($_[0]))};
	# Override if needed
	$self->{_entity_conversion} = $_[2] if $_[2];

	bless($self);
	return $self;
}

# Get a new character from the buffer
sub _read_char {
	my $self = shift;
	return chop $self->{_BUFFER};
}

sub get_token {

	my $self = shift;

	$self->{_TOKEN} = '';
	$self->{_ARGUMENT} = '';
	$self->{_CACHE} = '';
	$self->{_STATE} = '';

	until ($self->{_STATE} eq "done") { $self->process }

	if ($self->{_TOKEN} eq 'control') {
		return 'control', split(/\|/, $self->{_ARGUMENT});
	}

	return $self->{_TOKEN}, $self->{_ARGUMENT};

}

# Allows us to search for control words and jump to them. This will
# scroll through the buffer (be warned!)
sub jump_to_control_word {

	my $self = shift;

	my @stop_words = @_;

	while (1) {
		my ($type, $value, $args) = ($self->get_token, '');

		if ($type eq 'eof') { return 0; }

		if ($type eq 'control') {
			for (@stop_words) {
				if ($_ eq $value) {
					#print "*$value*$args*\n";
					$self->{_BUFFER} .= reverse "\\$value$args";
					return 1;
				}
			}
		}
	}
}

# Allows us to save the buffer at different states. The first arg
# is either 'save' or 'retr', the second is the bookmark name.
sub bookmark {

	my $self = shift;

	my $command = shift;
	my $bookmark = shift;

	if ($command eq 'save') {
		$self->{_BOOKMARKS}->{$bookmark} = $self->{_BUFFER};
	} elsif ($command eq 'retr') {
		$self->{_BUFFER} = $self->{_BOOKMARKS}->{$bookmark};
	} elsif ($command eq 'delete') {
		$self->{_BOOKMARKS}->{$bookmark} = undef;
	}

}

sub process {

	my $self = shift;

	my $character = $self->_read_char;

	if ($character eq "") {

		$self->{_STATE} = 'done';
		$self->{_TOKEN} = 'eof';
	}

	# No state ... go get one!
	if (!$self->{_STATE}) {
		$self->set_state($character);

	# So we started with a \ did we?
	} elsif ($self->{_STATE} eq "beginControl") {


		# Are we just escaping characters?
		if ($character =~ m!(['\\}{])!) {
			my $type = $1;

			# Escaped char value?
			if ($type eq "'") {
				$self->{_STATE} = 'text';
				$self->{_CACHE} = $self->get_entity;

			# Nope, escaped metachar
			} else {
				$self->{_STATE} = 'text';
				$self->{_CACHE} = $type;
			}

		# So here we are, reading the first char of a control sequence
		} else {
			$self->{_STATE} = 'controlSequence';
			$self->{_CACHE} = $character;
		}

	# We're reading in plain text
	} elsif ($self->{_STATE} eq "text") {


		# Check for non-printed White Space
		if ($character =~ m![\r\t\n]!) {

		# Check for opening of closing a group
		} elsif ($character =~ m!(}|{)!) {


			my $type = $1;

			# First we return it to the buffer
			$self->{_BUFFER} .= $type;

			# Then we return our plaintext so far...
			$self->{_ARGUMENT} = $self->{_CACHE};
			$self->{_TOKEN} = 'text';
			$self->{_STATE} = 'done';

		# Maybe we're a backslash...
		} elsif ($character =~ m!\\!) {


			# So we are. We need another character now to see
			# what to do.

			my $character2 = $self->_read_char;

			# Are we an entity?
			if ($character2 eq "'") {
				$self->{_CACHE} .= $self->get_entity;

			# Are we plain text?
			} elsif ($character2 =~ m![a-zA-Z]!) {
				# Return the char to the buffer
				$self->{_BUFFER} .= "$character2\\";
				$self->{_ARGUMENT} = $self->{_CACHE};
				$self->{_TOKEN} = 'text';
				$self->{_STATE} = 'done';

			# Guess we're an escaped char
			} else {
				$self->{_CACHE} .= $character2;
			}

		# So we're plain text
		} else {

			$self->{_CACHE} .= $character;
		}

	# Control Sequence names. Yay
	} elsif ($self->{_STATE} eq "controlSequence" ) {

		# I'm a letter
		if ($character =~ m![a-z]!i) {
			$self->{_CACHE} .= $character;

		# I'm a number or a sign
		} elsif ($character =~ m![\d-]!) {
			$self->{_CACHE} .= "|$character";
			$self->{_STATE} = 'controlSequenceArgument';

		# I'm a terminating space
		} elsif ($character =~ m!\s!) {
			$self->{_STATE} = 'done';
			$self->{_TOKEN} = 'control';
			$self->{_ARGUMENT} = $self->{_CACHE};

		# I'm something else. Return me to the buffer and return a token
		} else {
			$self->{_BUFFER} .= $character;
			$self->{_STATE} = 'done';
			$self->{_TOKEN} = 'control';
			$self->{_ARGUMENT} = $self->{_CACHE};
		}

	# Control Character arguments
	} elsif ($self->{_STATE} eq "controlSequenceArgument") {

		# I'm a number
		if ($character =~ m!\d!) {
			$self->{_CACHE} .= $character;

		# I'm a terminating space
		} elsif ($character =~ m!\s!) {
			$self->{_STATE} = 'done';
			$self->{_TOKEN} = 'control';
			$self->{_ARGUMENT} = $self->{_CACHE};

		# I'm something else. Return me to the buffer and return a token
		} else {
			$self->{_BUFFER} .= $character;
			$self->{_STATE} = 'done';
			$self->{_TOKEN} = 'control';
			$self->{_ARGUMENT} = $self->{_CACHE};
		}

	# We've hit the DONE state then
	} elsif ($self->{_STATE} eq 'done') {
		1;
	# Panic
	} else {
		die "I don't know this state... *$self->{_STATE}*";
	}

}

sub get_entity {

	my $self = shift;

	my $byte_value = $self->_read_char . $self->_read_char;

	my $entity = $self->{_entity_conversion}->($byte_value);

	return $entity;
}

sub set_state {

	my $self = shift;
	my $character = shift;

	# Opening a group
	if ($character eq "{") {
		$self->{_TOKEN} = 'group';
		$self->{_ARGUMENT} = 1;
		$self->{_STATE} = 'done';

	# Closing a group
	} elsif ($character eq "}") {
		$self->{_TOKEN} = 'group';
		$self->{_ARGUMENT} = 0;
		$self->{_STATE} = 'done';

	# Starting a control token
	} elsif ($character eq "\\") {
		$self->{_STATE} = 'beginControl';

	} elsif ($character =~ m![\r\n\t]!) {


	# Text
	} else {
		$self->{_CACHE} = $character;
		$self->{_STATE} = 'text';
	}

}

1;

__END__

=head1 NAME

RTF::Tokenizer - Tokenize RTF

=head1 DESCRIPTION

Tokenizes RTF

=head1 SYNOPSIS

  use RTF::Tokenizer;

  sub entity_handler {
    return "&#" . hex($_[0]);
  }

  my $object = RTF::Tokenizer->new($line);
  #my $object = RTF::Tokenizer->new($line, \&entity_handler);

  while (1) {
    my ($type, $value, $extra) = $object->get_token;
    print "$type, $value, $extra\n";
    if ($type eq 'eof') { exit; }
  }

  $rtf->bookmark('save', '_font_table_original');

  $rtf->jump_to_control_word('fonttbl');
  my ($la, $la, $la) = $rtf->get_token; # 'control', 'fonttbl'

  $rtf->bookmark('retr', '_font_table_original');

  $rtf->jump_to_control_word('rtf');
  my ($la, $la, $la) = $rtf->get_token; # 'control', 'rtf', 1

  $rtf->bookmark('retr', '_font_table_original');

  $rtf->bookmark('delete', '_font_table_original');

=head1 METHODS

=head2 new ( $data [, entity handling subroutine ] )

Creates an instance. Needs a string of RTF for the first argument
and an optional subroutine for the second. This subroutine is what
to do upon finding an entity. Default behaviour is to change it into
the character represented, but you can make it spit out HTML entities
if you want too (as per the example above). The argument passed to this
routine will be a hex value for the entity.

=head2 get_token

Returns a list, containing: token type (one of: control, text, group
or eof), token data, and then if it's a control word, the integer
value associated with it (if there is one).

=head2 bookmark ( action, name )

Saves a copy of the current buffer to a hash in the object, with the key
of 'name'. Possible actions are 'save', 'retr' and 'delete.' It's probably
a good idea, if you have a large amount of text, to delete your bookmarks
when done, because the hash contains a copy of the data, rather than a
position in the buffer. Font.pm contains a good example.

=head2 jump_to_control_word ( list of control words )

Goes through the buffer until it finds one of the control words. The next
token from C<get_token>, having done this, will be the control word. The
buffer up to this point will be lost (unless you've saved it.)

=head1 AUTHOR

Peter Sergeant E<lt>pete@clueball.comE<gt>

=head1 COPYRIGHT

Copyright 2002 Peter Sergeant.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
