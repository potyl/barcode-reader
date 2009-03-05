#!/usr/bin/perl

=head1 NAME

modify.pl - modify an image through Image::Magick

=head1 SYNOPSIS

modify.pl [OPTIONS] image

=head1 DESCRIPTION

Options:

	-h, --help  print this help message

=cut

use strict;
use warnings;

use Gtk2 '-init';
use Glib qw(TRUE FALSE);
use Pod::Usage;
use Getopt::Long qw(:config auto_help);
use Data::Dumper;
use Image::Magick;


exit main();


sub main {
	
	GetOptions() or pod2usage(1);
	pod2usage(1) unless @ARGV;
	my ($filename) = @ARGV;


	my $image = create_widgets($filename);
	
	my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($filename);
	Gtk2->main();
	return 0;
}


sub create_widgets {
	my ($filename) = @_;

	my $window = Gtk2::Window->new();
	
	my $button = Gtk2::Button->new('Modulate');
	
	my $magick = Image::Magick->new();
	$magick->Read($filename);

	my $image = Gtk2::Image->new();
	set_image_from_magick($image, $magick);

	# Callback invoked each time that a parameter is changed
	my %fields = ();
	my $modulate_change = sub {

print "Doing modulate\n";
		my %args = ();
		while (my ($field, $widgets) = each %fields) {
			my ($check, $scale) = @{ $widgets };
			if ($check->get_active) {
				$args{$field} = int($scale->get_value);
			}
		}
		print Dumper(\%args);
		my $copy = $magick->Clone();
		$copy->Modulate(%args);
		
		set_image_from_magick($image, $copy);
	};
	
	# The controls for the modulate
	my $table = Gtk2::Table->new(2, 2, FALSE);
	my $i = 0;
	my @fields = qw(brightness saturation hue lightness whiteness blackness);
	foreach my $field (@fields) {
		my ($check, $scale) = add_table_row($table, $field, $i++);
		$fields{$field} = [$check, $scale];
	}
	
	$button->signal_connect('clicked', $modulate_change);
	
	
	# Widget packing
	my $frame = Gtk2::Frame->new('Modulate');
	$frame->add($table);
	
	my $vbox = Gtk2::VBox->new(FALSE, 0);
	$vbox->pack_start($image, TRUE, TRUE, 0);
	$vbox->pack_start($frame, TRUE, TRUE, 0);
	$vbox->pack_start($button, FALSE, FALSE, 0);
	
	$window->add($vbox);
	
	
	# Connect the callbacks
	$window->signal_connect('delete-event' => sub {
		Gtk2->main_quit();
	});
	
	$window->show_all();
	$window->set_size_request(600, 400);
	
	
	return $image;
}


sub set_image_from_magick {
	my ($image, $magick) = @_;

	my $loader = Gtk2::Gdk::PixbufLoader->new();
	$loader->write($magick->ImageToBlob());
	$loader->close();
	my $pixbuf = $loader->get_pixbuf;
	$image->set_from_pixbuf($pixbuf);
}


#
# Adds a row to the table (check: scale) and returns the widgets.
#
sub add_table_row {
	my ($table, $label_text, $pos) = @_;

	my $check = Gtk2::CheckButton->new_with_label("\u$label_text: ");
	$table->attach($check, 0, 1, $pos, $pos + 1, ['fill'], [], 0, 0);
	
	my $scale = Gtk2::HScale->new_with_range(0, 100, 10);
	$scale->set_value(50);
	$scale->set_sensitive(FALSE);
	$table->attach($scale, 1, 2, $pos, $pos + 1, ['expand', 'fill'], [], 0, 0);

	$check->signal_connect('toggled' => sub {
		$scale->set_sensitive($check->get_active);
	});

	return ($check, $scale);
}
