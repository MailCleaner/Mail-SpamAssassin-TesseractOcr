package Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess;

use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT);
use Carp qw(croak);

our $VERSION = '1.1.0';

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw (
    createImage
    loadImage
    saveImage
    releaseImage
    getWidth
    getHeight
    getDepth
    getChannels
    toGray
    edges
);

our @EXPORT = ();

BEGIN {
    my $VERSION = '1.1.0';
    require XSLoader;
    XSLoader::load(__PACKAGE__,$VERSION);
    require Exporter;
    push @ISA, 'Exporter';
}

sub convert {
    my ($self, $in, $out) = @_;
    my $pp = Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess->new();
    my $ii = $pp->loadImage($in);
    my $err = $pp->saveImage($out,$ii);
    $pp->releaseImage($ii);
    return $err;
}

sub preprocess {
    my ($self, $in, $out) = @_;
    my $pp = Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess->new();
    my $ii = $pp->loadImage($in);

    # TODO - All preprocessing steps

    my $err = $pp->saveImage($out,$ii);
    $pp->releaseImage($ii);
    return $err;
}

sub createImage {
    my ($self, $width, $height, $depth, $channels) = @_;
    return &cvCreateImage($width,$height,$depth,$channels);
}

sub loadImage {
    my ($self, $filename) = @_;
    return &cvLoadImage($filename);
}

sub saveImage {
    my ($self, $filename, $image) = @_;
    &cvSaveImage($filename,$image,0);
}

sub getWidth {
    my ($self,$image) = @_;
    return &cvGetWidth($image);
}

sub getHeight {
    my ($self,$image) = @_;
    return &cvGetHeight($image);
}

sub getDepth {
    my ($self,$image) = @_;
    return &cvGetDepth($image);
}

sub getChannels {
    my ($self,$image) = @_;
    return &cvGetChannels($image);
}

sub addBorder {
    my ($self,$image) = @_;
    return &cvAddBorder($image);
}

sub split {
    my ($self,$image,$red,$green,$blue) = @_;
    &cvSplit($image,$red,$green,$blue,undef);
}

sub blur {
    my ($self,$image,$x,$y) = @_;
    return &cvBlur($image,$x,$y);
}

sub toGray {
    my ($self,$image) = @_;
    return &cvToGray($image);
}

sub toBlack {
    my ($self,$image) = @_;
    &cvToGray($image);
}

sub edges {
    my ($self,$in,$out) = @_;
    &cvZero($out);
    &cvCanny($in,$out,20.0,25.0,3);
    return $out;
}

1;
