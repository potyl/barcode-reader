#!/usr/bin/perl

=head1 NAME

barcode-isbn.pl - parse an ISBN barcode

=head1 SYNOPSIS

barcode-isbn.pl [OPTIONS] image

=head1 DESCRIPTION

Options:

	-h, --help  print this help message

This program parses an image and extracts the barcode information. The barcode
is expected to be an ISBN barcode.

=cut

use strict;
use warnings;

use Gtk2 '-init';
use Pod::Usage;
use Getopt::Long qw(:config auto_help);
use Data::Dumper;


exit main();


sub main {
	
	GetOptions() or pod2usage(1);
	pod2usage(1) unless @ARGV;
	my ($filename) = @ARGV;

	my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($filename);
	my $isbn = get_isbn($pixbuf);
	
	print "ISBN = $isbn\n";
	return 0;
}


sub get_isbn {
	my ($pixbuf) = @_;
	my ($width, $height) = ($pixbuf->get_width, $pixbuf->get_height);
	print "(\$width, \$height) = ($width, $height)\n";
	
	
	my $y = int($height/2);
	my $bits = get_bitmap_scanline($pixbuf, $y);
	print $bits, "\n";
	
	return "NOTHING";
}


#
# Returns a text string of 1 and 0 where 1 means that a color pixel was found
# and 0 that a background color was found.
#
sub get_bitmap_scanline {
	my ($pixbuf, $y) = @_;
	
	my $width = $pixbuf->get_width;
	my @bits = ();
	for (my $x = 0; $x < $width; ++$x) {
		my ($r, $g, $b) = get_pixel($pixbuf, $x, $y);
		
		my ($bit) = ($r || $g || $b ? 1 : 0);
		push @bits, $bit;
#		printf "(x: %3d, y: %3d) = (r: 0x%02x, g: 0x%02x, b: 0x%02x)\n", $x, $y, $r, $g, $b;
	}
	
	my $bits = join '', @bits;
	$bits =~ s/^0+//g;
	$bits =~ s/0+$//g;
#	print $bits, "\n";
	return $bits;
}


#
# Returns the pixel at the given coordinate. The pixel returned is in (rgba).
#
sub get_pixel {
	my ($pixbuf, $x, $y) = @_;
	
	my $pos = $pixbuf->get_rowstride * $y + $pixbuf->get_n_channels * $x;
	# Note this is far from optimal as the pixels are fetched from the image each time!
	my ($r, $g, $b, $a) = unpack "C*", substr $pixbuf->get_pixels, $pos, $pixbuf->get_n_channels;
	return ($r, $g, $b, $a);
}


