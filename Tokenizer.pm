# RTF::Tokenizer 0.01

# by Peter Sergeant <pete@clueball.com>

# Magic Package Stuff


require 5;
package RTF::Tokenizer;
use strict;
$VERSION = 0.01;

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
		} elsif ($character =~ m![\d+-]!) {
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

=head1 METHODS

=head2 new

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

=head1 AUTHOR

Peter Sergeant E<lt>pete@clueball.comE<gt>

=head1 COPYRIGHT

Copyright 2002 Peter Sergeant.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

