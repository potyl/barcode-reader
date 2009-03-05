#!/usr/bin/perl

=head1 NAME

Scanner - ISBN barcode scanner.

=head1 SYNOPSIS

	use Scanner;
	
	my $scanner = Scanner->new($bits);
	my $isbn = $scanner->get_isbn();

=head1 DESCRIPTION

This package provides a simple ISBN barcode scanner. This scanner requires a
series of bits indicating where black is seen (1) and where nothing is seen (0).

=cut


package Scanner;

use strict;
use warnings;
use base 'Class::Accessor::Fast';

use Carp;
use Image::Magick;

__PACKAGE__->mk_accessors(
	qw(
		bits
		pos
		color
		length
		unit
	)
);


# The bar codes as bar units each digit show the length of each bar. The bars
# are alternating color. For instance the digit '0' is composed of a 3 units
# bar, followed a by a 2 units bar of alternate color, followed by 1 unit bar of
# color and ending with a 1 unit bar of alternate color. This means that '0' is
# represented as '|||..|.' or '...||.|' depending of the first color.
my %DIGITS = (
	3211 => 0,
	1123 => 0,
	1222 => 1,
	2221 => 1,
	2122 => 2,
	1411 => 3,
	1141 => 3,
	1132 => 4,
	2311 => 4,
	1231 => 5,
	4111 => 6,
	1114 => 6,
	1312 => 7,
	2131 => 7,
	3121 => 8,
	1213 => 8,
	3112 => 9,
	2113 => 9,
);


sub new {
	my $class = shift;
	my ($bits) = @_;

	my $self = bless {}, ref($class) || $class;
	$self->bits([split //, $bits]);
	$self->pos(0);
	$self->color($self->bits->[0]);
	$self->length(scalar @{$self->bits});
	$self->unit(1);
	
	return $self;
}


sub scan_isbn_13 {
	my $self = shift;
	
	# Place the reader at the beginning of the barcode by scanning all white noise
	$self->scan_bar();

printf "Bits: %s\n", join('', @{$self->bits}[$self->pos .. $self->length - 1]);
	
	# Scan the barcode start "|_|"
	$self->scan_border_guard();
	
	my @isbn = (9); # An ISBN starts with 9
	
	# Scan 6 digits
	for (my $i = 0; $i < 6; ++$i) {
		my $start = $self->pos;
		my $digit = $self->scan_digit();
		my $end = $self->pos - 1;
		printf "%d > %d %s\n\n", $i + 1, $digit, ( join '', @{$self->{bits}}[$start .. $end]  );
		push @isbn, $digit;
	}
	
	
	# Scan the middle guard separator "_|_|_"
	$self->scan_middle_guard();
	
	# Scan the last 6 digits
	for (my $i = 6; $i < 12; ++$i) {
		my $start = $self->pos;
		my $digit = $self->scan_digit();
		my $end = $self->pos - 1;
		printf "%d > %d %s\n\n", $i + 1, $digit, ( join '', @{$self->{bits}}[$start .. $end]  );
		push @isbn, $digit;
	}

	my $checksum = checksum_isbn_13(@isbn);
	
	if ($checksum != $isbn[-1]) {
		die "Checksum failed expected $isbn[-1] but got $checksum";
	}
print "checksum = $checksum\n";
	
	return join '', @isbn;
}


#
# Computes the checksum of an ISBN-10.
#
sub checksum_isbn_10 {
	my (@isbn) = @_;

	
	# Compute the checksum
	my $checksum = 0;
	for my $i (1 .. 9) {
		my $val = $i * $isbn[$i - 1];
		print "Addig $val = %d x %d\n";
		$checksum += $val;
	}
	$checksum %= 11;
	$checksum  = 'X' if $checksum == 10;
	
	return $checksum;
}


#
# Computes the checksum of an ISBN-13.
#
sub checksum_isbn_13 {
	my (@isbn) = @_;
#@isbn = (split //, '978030640615');
	
	# Compute the checksum
	my $checksum = 0;
	my $flip = 0;
	for my $i (1 .. 12) {
		
		my ($factor) = (($flip = !$flip) ? 1 : 3);
		
		my $val = $factor * $isbn[$i - 1];
		printf "Addig %2d = %dx%d\n", $val, $isbn[$i - 1], $factor;
		$checksum += $val;
	}

	$checksum = (10 - ($checksum % 10) ) % 10;
	
	return $checksum;
}


#
# Scans the tall middle guard separator "_|_|_" used to separate the two parts
# of the ISBN
#
sub scan_middle_guard {
	my $self = shift;

	my @parts = ();
	for (my $i = 0; $i < 5; ++$i) {
		my $length = $self->scan_bar();
		push @parts, $length;
	}
	
	my $first = $parts[0];
	foreach my $current (@parts) {
		if ($first != $current) {
			die "Middle guard has different size bars (@parts)";
		}
	}
}


#
# Scans the tall border guards used at the beginning and at the end of the
# barcode.
#
sub scan_border_guard {
	my $self = shift;

	# Scan the barcode start "|_|"
	my $start_bar1  = $self->scan_bar();
	my $start_space = $self->scan_bar();
	my $start_bar2  = $self->scan_bar();
	
	# The length of the start has to be constant
	my $unit = $start_bar1;
	if ($start_bar1 != $start_space or $start_bar1 != $start_bar2) {
		$unit = ($start_bar1 + $start_space + $start_bar2)/3;
		warn "Border guard has different size bars ($start_bar1, $start_space, $start_bar2) using average $unit";
	}
	$self->unit($unit);
	printf "bar unit = %s\n", $self->unit;
}


#
# Scans the next bars until a digit is found. This method will read the extra
# padding after the digit.
#
sub scan_digit {
	my $self = shift;
	
	my $label = "at pos [" . $self->pos;
	my $c1 = $self->scan_bar();
	my $c2 = $self->scan_bar();
	my $c3 = $self->scan_bar();
	my $c4 = $self->scan_bar();
	$label .= ", " . $self->pos . "]";
	
	print "c1 = $c1\n";
	print "c2 = $c2\n";
	print "c3 = $c3\n";
	print "c4 = $c4\n";
	
	# Digits are encoded in a 7 units wide space
	my $length = $c1 + $c2 + $c3 + $c4;
	if ($length != 7) {
		die "Digit length is not encoded in 7 units ($length) at $label";
	}
	
	# Returns the digit corresponding the the code
	my $code = join '', $c1, $c2, $c3, $c4;
	if (! exists $DIGITS{$code}) {
		die "Can't find digit for code $code at $label";
	}
	my $digit = $DIGITS{$code};
	return $digit;
}


#
# Scans the current bar until there's a color change. This method returns the
# length of the bar scanned and places pos at the beginnig of the next bar. The
# length is returned in units (the number of bits used by the bar divided by the
# unit size).
#
sub scan_bar {
	my $self = shift;
	
	my $start = $self->pos;
	
	for (; $self->{pos} < $self->length; ++$self->{pos}) {
		my $color = $self->bits->[$self->{pos}];
		if ($color != $self->color) {
			$self->color($color);
			last;
		}
	}
	
	my $length = ($self->pos - $start)/$self->unit;
	return $length;
}


#
# Returns the ISBN 13 contained in the givne image.
#
sub get_isbn_13 {
	my ($filename) = @_;

	my $image = Image::Magick->new();
	my $error = $image->Read($filename);
	croak "Failed to read $filename: $error" if $error;

	
	# Get the middle scanline as a bit string
	my $y = int($image->Get('height')/2);
	my $bits = get_bitmap_scanline($image, $y);

{
	my $width = $image->Get('width');

	my $copy =  Image::Magick->new(size => "${width}x1");
	$copy->ReadImage('xc:red');

print "Image middle is at pixel $y\n";
	foreach my $x (0 .. $width - 1) {
		my @color = $image->GetPixel(x => $x, y => $y, normalize => 1);
		$copy->SetPixel(x => $x, y => 0, color => \@color);
	}
#	$copy->WhiteThreshold(240);
	$copy->Modulate(brighness => 0.1);
	$copy->Write(filename => 'a.png');
	
	$image->Modulate(hue => 0.5);
	$image->Write(filename => 'i.png');
}

print "Bits: $bits\n";	
	my $scanner = Scanner->new($bits);
	my $isbn = $scanner->scan_isbn_13();
	return $isbn;
}


#
# Returns a text string of 1 and 0 where 1 means that a color pixel was found
# and 0 that a background color was found.
#
sub get_bitmap_scanline {
	my ($image, $y) = @_;


	my $width = $image->Get('width');

	my @bits = ();
	my $threshold = 0x18ff;
	for (my $x = 0; $x < $width; ++$x) {
		my ($r, $g, $b) = $image->GetPixel(x => $x, y => $y, normalize => 0);
		
		# 0 -> nothing, 1 -> pixel of black thickness
		my ($bit) = ($r < $threshold && $g < $threshold && $b < $threshold ? 1 : 0);

		
#		my ($bit) = ($r || $g || $b ? 0 : 1);
		push @bits, $bit;
#		printf "(x: %3d, y: %3d) = (r: 0x%04x, g: 0x%04x, b: 0x%04x) : %d\n", $x, $y, $r, $g, $b, $bit;
	}
#die "Here\n";
	my $bits = join '', @bits;
	return $bits;
}


1;
