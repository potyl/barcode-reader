#!/usr/bin/perl

=head1 NAME

magick-isbn.pl - parse an ISBN barcode

=head1 SYNOPSIS

magick-isbn.pl [OPTIONS] image

=head1 DESCRIPTION

Options:

	-h, --help  print this help message

This program parses an image and extracts the barcode information. The barcode
is expected to be an ISBN barcode.

=cut

use strict;
use warnings;

use Image::Magick;
use Pod::Usage;
use Getopt::Long qw(:config auto_help);
use Data::Dumper;


# The bar codes as bar units each digit show the length of each bar. The bars
# are alternating color. For instance the digit '0' is composed of a 3 units
# bar, followed a by a 2 units bar of alternate color, followed by 1 unit bar of
# color and ending with a 1 unit bar of alternate color. This means that '0' is
# represented as '|||..|.' or '...||.|' depending of the first color.
my %DIGITS = (
	3211 => 0,
	2221 => 1,
	2122 => 2,
	1411 => 3,
	1132 => 4,
	1231 => 5,
	1114 => 6,
	1312 => 7,
	1213 => 8,
	3112 => 9
);


exit main();


sub main {
	
	GetOptions() or pod2usage(1);
	pod2usage(1) unless @ARGV;
	my ($filename) = @ARGV;

	my $image = Image::Magick->new();
	$image->Read($filename);
	my $isbn = get_isbn($image);
	
	print "ISBN = $isbn\n";
	
	return 0;
}


sub get_isbn {
	my ($image) = @_;
	my ($width, $height) = $image->Get('width', 'height');
	
	# Get the middle scanline as a bit string
	my $y = int($height/2);
	my $bits = get_bitmap_scanline($image, $y);


	# Trim the border padding from the scan line
	$bits =~ s/^0+//g;
	$bits =~ s/0+$//g;
	
	
	# Remove the border bars
	$bits =~ s/^110011//;
	$bits =~ s/110011$//;

	print "bits: $bits\n";

	# The middle part
	while ($bits =~ /0011001100/g) {
		print "Matched middle\n";
	}

	
	my @bits = split //, $bits;
	my $step = 14; # The number of bars per digit
	my $count = 0; # The characters scanned count
	my $pos = 0;
	for (;$pos < @bits; $pos += $step) {
		++$count;
		my $max = $pos + $step - 1;
		$max = @bits - 1 if $max >= @bits;
		my @chunk = @bits[$pos .. $max];
		
		my $digit = get_isbn_digit(2, @chunk); # 2 -> number of bits per bar
		printf "%2d %s -> %d\n", $count, join('', @chunk), $digit;
		
		if ($count == 6) {
			print "First part\n";
			last;
		}
	}
	
	printf "Next: %s\n", join '', @bits[$pos .. $pos + 10 - 1];
	
	
	return "NOTHING";
}


#
# Returns a digit from an ISBN a chunk of bits. This function needs the length
# of the thinest bar in order to find the code of the digit.
#
sub get_isbn_digit {
	my ($size, @bits) = @_;
	
	printf "%s\n", join('', @bits);
	
	my @code = ();
	
	# The digits are encoded in 4 bars of alterning color
	my $current = $bits[0];
	my $start = 0;
	my $pos = 0; 
	for (; $pos < @bits; ++$pos) {
		my $color = $bits[$pos];
#		printf "%2d) current: $current, color: $color\n", $pos;
		if ($current != $color) {
			# Section change
			my $span = ($pos - $start)/$size;
#			printf "Span $span, pos = $pos, start = $start, length = %d\n\n", ($pos - $start);
			push @code, $span;
			$start = $pos;
			$current = $color;
		}
	}
	
	my $span = ($pos - $start)/$size;
#	printf "Span $span, pos = $pos, start = $start, length = %d\n\n", ($pos - $start);
	push @code, $span;
	
	my $code = join '', @code;
	if (! exists $DIGITS{$code}) {
		my $chunk = join '', @bits;
		die "Can't find digit for code $code encoded in $chunk";
	}
	my $digit = $DIGITS{$code};

	printf 	"%4s > %d %s\n", $code, $digit, join('', @bits);
	return $digit;
}


#
# Returns a text string of 1 and 0 where 1 means that a color pixel was found
# and 0 that a background color was found.
#
sub get_bitmap_scanline {
	my ($image, $y) = @_;


	my $width = $image->Get('width');

	my @bits = ();
	for (my $x = 0; $x < $width; ++$x) {
		my ($r, $g, $b) = get_pixel($image, $x, $y);
		
		# 0 -> nothing, 1 -> pixel of black thickness
		my ($bit) = ($r || $g || $b ? 0 : 1);
		push @bits, $bit;
#		printf "(x: %3d, y: %3d) = (r: 0x%02x, g: 0x%02x, b: 0x%02x)\n", $x, $y, $r, $g, $b;
	}
	
	my $bits = join '', @bits;
	return $bits;
}


#
# Returns the pixel at the given coordinate. The pixel returned is in (rgba).
#
sub get_pixel {
	my ($image, $x, $y) = @_;
	return $image->GetPixel(x => $x, y => $y, normalize => 0);
}


