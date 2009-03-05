#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

use Scanner;


exit main();


sub main {
	
	my @isbn = qw(
		934-7-93397-432-1
		970-1-56091-470-7
		976-1-56592-479-8
	);
	
	foreach my $isbn (@isbn) {
		test_isbn($isbn);
	}
	
	return 0;
}


sub test_isbn {
	my ($isbn) = @_;
	
	my $filename = "samples/$isbn.png";
	print "$filename\n";
	
	my $expected = $isbn;
#	$expected =~ s/^\d//;
#	$expected =~ s/\d$//;
	$expected =~ s/-//g;

	my $got = Scanner::get_isbn_13($filename);
	
	is($got, $expected, "Parsing $isbn");
	
	return $isbn;
}
