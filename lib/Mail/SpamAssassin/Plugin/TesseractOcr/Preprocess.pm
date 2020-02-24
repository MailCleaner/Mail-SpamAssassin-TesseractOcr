package Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess;

use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT);
use Carp qw(croak);

our $VERSION = '3.00';

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
    toColor
    edges
    contours
    convert
    preprocess
);

our @EXPORT = ();

BEGIN {
    my $VERSION = '3.00';
    require XSLoader;
    XSLoader::load(__PACKAGE__,$VERSION);
    require Exporter;
    push @ISA, 'Exporter';
}

sub convert {
    my ($self, $in, $out) = @_;
    my $pp = Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess->new();

    # Open Image
    my $ii = $pp->loadImage($in);

    # Store with new name
    $pp->saveImage($out,$ii);

    # Release Image
    $pp->releaseImage($ii);
}

sub preprocess {
    my ($self, $in, $out) = @_;
    my $pp = Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess->new();

    # Open Image
    my $ii = $pp->loadImage($in);

    # Add border
    $ii = $pp->addBorder($ii);

    # Get Image Stats
    my $x = $pp->getWidth($ii);
    my $y = $pp->getHeight($ii);
    my $z = $pp->getDepth($ii);
    my $c = $pp->getChannels($ii);

    # Split channels
    my @channels;
    if ($c == 1) {
        push @channels, $ii;
    } else {
        push @channels, $pp->createImage($x,$y,$z,1);
        push @channels, $pp->createImage($x,$y,$z,1);
        push @channels, $pp->createImage($x,$y,$z,1);
        $pp->split($ii,$channels[0],$channels[1],$channels[2]);
    }

    # Collect edges from all channels
    my $edges = $pp->createImage($x,$y,$z,1);
    for (my $i = 0; $i < $c; $i++) {
        $channels[$i] = $pp->blur($channels[$i],2,2);
        $pp->threshold($channels[$i],0,3);
        my $edge = $pp->createImage($x,$y,$z,1);
        $edge = $pp->edges($channels[$i],$edge);
        $edges = $pp->merge($edges,$edge);
    }
    # Slight blur to merge edges
    $edges = $pp->blur($edges,2,2);

    # Find the contours
    my $contours = $pp->contours($edges);

    # Greyscale and Invert on order to isolate text
    $ii = $pp->toGray($ii);
    $ii = $pp->invert($ii);

    # Mask all uninteresting content
    $ii = $pp->mask($ii,$contours);

    # Set mask back to white
    $ii = $pp->invert($ii);

    # Store with new name
    $pp->saveImage($out,$ii);

    # Release Image
    $pp->releaseImage($ii);
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
    my $params = 0;
    &cvSaveImage($filename,$image,\$params);
    if ( -e $filename ) {
        return 1;
    } else {
        return 0;
    }
}

sub releaseImage {
    my ($self, $image) = @_;
    &cvRelease($image);
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

sub toColor {
    my ($self,$image) = @_;
    return &cvToColor($image);
}

sub toBlack {
    my ($self,$image) = @_;
    &cvToGray($image);
}

sub edges {
    my ($self,$in,$out) = @_;
    &cvZero($out);
    &cvCanny($in,$out,200.0,250.0,3);
    return $out;
}

sub merge {
    my ($self,$img1,$img2) = @_;
    &cvAdd($img1,$img2,$img1,undef);
    return $img1;
}

sub invert {
    my ($self, $image) = @_;
    return &cvInvert($image);
}

sub contours {
    my ($self,$edges) = @_;
    return &cvContours($edges);
}

sub mask {
    my ($self,$image,$mask) = @_;
    return &cvMask($image,$mask);
}

sub threshold {
    my ($self,$image,$method,$size) = @_;
    &cvAdaptiveThreshold($image,$image,255,$method,1,$size,5);
    return $image;
}

1;
