#!/usr/bin/perl

=head1 NAME

scanner.pl - parse an ISBN barcode

=head1 SYNOPSIS

scanner.pl [OPTIONS] image

=head1 DESCRIPTION

Options:

	-h, --help  print this help message

This program parses an image and extracts the barcode information. The barcode
is expected to be an ISBN barcode.

=cut

use strict;
use warnings;

use Scanner;
use Pod::Usage;
use Getopt::Long qw(:config auto_help);
use Data::Dumper;


exit main();


sub main {
	
	GetOptions() or pod2usage(1);
	pod2usage(1) unless @ARGV;
	my ($filename) = @ARGV;

	my $isbn = Scanner::get_isbn_13($filename);
	
	print "ISBN = $isbn\n";
	return 0;
}
