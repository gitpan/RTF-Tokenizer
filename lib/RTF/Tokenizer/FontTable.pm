#!/usr/local/bin/perl

# Return the font-table as a data structure

require 5;
package RTF::Tokenizer::FontTable;
use RTF::Tokenizer;
use vars qw($VERSION);
use strict;
my $VERSION = '0.02.1';


# A list of the properties we might expect...
# family, pitch, charset, fbias, cpg, embedded_encoding, panose, embedded_font_data
# embedded_font_file, untagged, face


sub get_table {

	# Grab the original object
	my $rtf = $_[0];

	# Save a copy of the buffer
	$rtf->bookmark('save', '_font_table_original');

	# Jump to the font table
	$rtf->jump_to_control_word('fonttbl');

	# The first entry will be the fonttable control word itself
	$rtf->get_token;

	# We're in a group here. When this group ends, the font table
	# has ended, and that's what we break on
	my $group = 1;

	# This will hold our font styles
	my %font_styles;

	# This holds the name of the font style we're currently dealing with
	my $current_font;

	# Text-type - tells us what kind of text to expect
	my $text_type = 'text';

	while ($group) {

		my ($type, $value, $args) = $rtf->get_token;

		#print "$type - $value - $args - F: $current_font - G: $group - P: $text_type\n";

		if ($type eq 'group') {

			# Either increment of decrement $group depending on if it's
			# open or closed, true or false.
			if ($value == 1) {
				$group++;
			} else {
				$group--;
				$text_type = 'text';
			}

		} elsif ($type eq 'control') {

			# New font declaration
			if ($value eq 'f') {
				$font_styles{$args} = {};
				$current_font = $args;

			# Font family
			} elsif ($value =~ m/^f(nil|roman|swiss|modern|script|decor|tech|bidi)$/) {
				$font_styles{$current_font}->{'family'} = $1;

			# Panose. YUCK YUCK YUCK
			} elsif ($value eq 'panose') {
				$text_type = 'panose';

			# Pitch
			} elsif ($value eq 'fprq') {
				$font_styles{$current_font}->{'pitch'} = $args;

			# Charset
			} elsif ($value eq 'fcharset') {
				$font_styles{$current_font}->{'charset'} = $args;

			# Bias
			} elsif ($value eq 'fbias') {
				$font_styles{$current_font}->{'bias'} = $args;

			# Codepage
			} elsif ($value eq 'cpg') {
				$font_styles{$current_font}->{'codepage'} = $args;


			# Untagged Font Name
			} elsif ($value eq 'fname') {
				$text_type = 'fname';

			# Embedded font - YUCK!
			} elsif ($value eq 'fontemb') {
				$text_type = 'fontemb';

			# Embedded font file - YUCK!
			} elsif ($value eq 'fontfile') {
				$text_type = 'fontfile';

			# Embedded font type
			} elsif ($value =~ m/(ftnil|ft?truetype)/) {
				$font_styles{$current_font}->{'embedded_encoding'} = $1;
			}

		} elsif ($type eq 'text') {


			# Deal with panose
			if ($text_type eq 'panose') {

				# Unencode the panose (10 pairs of hex)
				#($value = $value) =~ s/(..)/hex($1)/eg;

				$font_styles{$current_font}->{'panose'} = $value;

				$text_type = 'text';

			# Embedded Font
			} elsif ($text_type eq 'fontemb') {
				$font_styles{$current_font}->{'embedded_font_data'} = $value;
				$text_type = 'text';

			# Embeded Font Filename
			} elsif ($text_type eq 'fontfile') {
				$font_styles{$current_font}->{'embedded_font_file'} = $value;
				$text_type = 'text';

			# Untagged font name
			} elsif ($text_type eq 'fname') {
				$value =~ s/;$//;
				$font_styles{$current_font}->{'untagged'} = $value;
				$text_type = 'text';

			# For plain text, which can only be a font name
			} elsif ( $text_type eq 'text' ) {
				$value =~ s/;$//;
				$font_styles{$current_font}->{'face'} = $value;
			}

		}

	}

	$rtf->bookmark('retr', '_font_table_original');
	$rtf->bookmark('delete', '_font_table_original');

	return \%font_styles;
}

1;

__END__

=head1 NAME

RTF::Tokenizer::FontTable - Retrieve Fonttable info from an RTF file

=head1 DESCRIPTION

Represents RTF font tables as a data structure

=head1 SYNOPSIS

  use RTF::Tokenizer;
  use RTF::Tokenizer::FontTable;

  # Create the initial object
  my $rtf = RTF::Tokenizer->new($data);

  # Grab the font table info
  my %font_hash = %{RTF::Tokenizer::FontTable::get_table($rtf)};

=head1 METHODS

=head2 get_table ( RTF::Tokenizer object )

Returns a hash reference to the data structure containing font information.
This will be like {'1' => {} }, where the values inside the nested hash are
likely to be one of:
family, pitch, charset, fbias, cpg, embedded_encoding, panose, embedded_font_data,
embedded_font_file, untagged, face. Most of these are explained in the RTF spec.

=head1 AUTHOR

Peter Sergeant E<lt>pete@clueball.comE<gt>

=head1 COPYRIGHT

Copyright 2002 Peter Sergeant.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
