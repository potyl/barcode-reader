#!/usr/bin/perl                                                                 

use strict;
use warnings;

use GD;
use FindBin;
use Getopt::Long;
use File::Basename;
use Data::Dumper;
#use Math::Round;

use sort '_quicksort';

exit main();

sub main {

	my ($filename) = @ARGV ? @ARGV : 'image-barcode.png';
	my $source_res  = GD::Image->newFromPng($filename, 1);
	my ($source_width, $source_height) = $source_res->getBounds();
	my %positions = calibrate($source_res, $source_width, $source_height);

	my $step    = 0;
	my $oldval;
	my $newbit  = 0;
	my $cntbit  = 0;    #counter how many bits is in current color
	my @barcode;
	my $line    = 0;    #counter of barcede lines (doesn't matter about units)
	my $unittmp = 0;
	my $unit    = 0;    #size of unit, will be counted after 3rd line

	foreach my $key (sort by_number (keys(%positions)) ) {

		if ($step > 0) {
			my $curval = $positions{$key};
			my $change;

			$change = int(100-100*$oldval/$curval);

			if ($change>20 and $newbit==1) {
				if ($cntbit > 0) {
					if ( $unit > 0 ) {
						print "1\t$cntbit\t".round($cntbit/$unit)."\n";
					}
					if ( $line > 0 and $line < 4 ) {
						$unittmp+=$cntbit;
					}
					$line++;
				}
				$newbit = 0;
				$cntbit = 0;
			} elsif ($change<-20 and $newbit==0) {
				if ($cntbit > 0) {
					if ( $unit > 0 ) {
						print "0\t$cntbit\t".round($cntbit/$unit)."\n";
					}

					if ( $line > 0 and $line < 4 ) {
						$unittmp+=$cntbit;
					}
					$line++;
				}
				$newbit = 1;
				$cntbit = 0;
			}

			if ( $line == 4 and $unit == 0 ) {
				$unit = round($unittmp/3) + 1;
				print "unit: $unit\n";
			}

			$cntbit++;

#			print $newbit, "\t", $key,' ',%positions->{$key}, ' ', $change , "\n";
		}

		$oldval = $positions{$key};
		$step++;
	}

	return 0;
}

sub calibrate {
	my $source_res  = shift;
	my $width       = shift;
	my $height      = shift;

#	print "$width, $height\n";

	my $basewindow  = 3;
	my $positions;

	my $hpos = $height/2;

	for (my $i = 0; $i<$width - $basewindow; $i++) {

		my $winR = 0;
		my $winG = 0;
		my $winB = 0;

		for (my $win = 0; $win < $basewindow; $win++) {
			my $color = $source_res->getPixel($i+$win, $hpos);
			my ($r, $g, $b) = $source_res->rgb($color);

			$winR+=$r;
			$winG+=$g;
			$winB+=$b;
		}

		$winR/=$basewindow;
		$winG/=$basewindow;
		$winB/=$basewindow;

#		$i += int($basewindow/2);

		my $ndx = int ( $i+$basewindow/2 );
		$positions->{$ndx} = int( getLuminocity($winR, $winG, $winB) );
#		print $ndx," ",$positions->{$ndx}, "\n";
	}

	return %{$positions};
}

sub getLuminocity {
	my ($r, $g, $b) = @_;

	return ($b - 1.77 * ( ($g-$b+(0.174*($r-$b)/1.403)) / (-2.114-0.174*1.77/1.403) ));
}

sub by_number {
	$a <=> $b;
}

sub round {
	my($number) = shift;
	return int($number + .5);
}

