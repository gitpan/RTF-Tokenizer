#!/usr/local/bin/perl

# RTF to CSS - Create a CSS file based on font tables in an RTF file

use RTF::Tokenizer;
use RTF::Tokenizer::FontTable;

use strict;
use Data::Dumper;

# Open the specified file and stringify it

open(FILE, $ARGV[0])||die$!;
my $data = join '', <FILE>;
close FILE;

# Create the initial object
my $rtf = RTF::Tokenizer->new($data);

# Grab the font table info
my %font_hash = %{RTF::Tokenizer::FontTable::get_table($rtf)};

# Define our family mappings:
my %font_families = (
	'roman' => 'serif',
	'swiss' => 'sans-serif',
	'modern' => 'sans-serif',
	'script' => 'cursive',
	'decor' => 'cursive',
	'tech' => 'monospace'
);


foreach my $style (keys %font_hash) {

	print "<div style = '\n";

	# Font family
		my $font_broad_family = $font_families{$font_hash{$style}{'family'}};
		my $font_exact = $font_hash{$style}{'face'};
		my $font_broad = $font_hash{$style}{'untagged'};

		my $font_family;
		if ($font_broad_family) { $font_family = $font_broad_family }
		if ($font_broad) { $font_family = "\"$font_broad\", " . $font_family }
		if ($font_exact) { $font_family = "\"$font_exact\", " . $font_family }
		$font_family =~ s/, $//;
		if ($font_family) {
			print "\tfont-family: $font_family;\n";
		}

	# Panose
		if ($font_hash{$style}{'panose'}) {
			my $panose = $font_hash{$style}{'panose'};
			$panose =~ s/(..)/hex($1)/g;
		}

	print "'>\n\n";
	print "$font_family;</div>\n"

}

