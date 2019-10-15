package Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess;

use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT);
use Carp qw(croak);

our $VERSION = '1.1.0';

BEGIN {
    my $VERSION = '1.1.0';
    require XSLoader;
    XSLoader::load(__PACKAGE__,$VERSION);
    require Exporter;
    push @ISA, 'Exporter';
}

sub convert {
    my ($in, $out) = @_;
    if ( !defined($in) || !defined($out) ) {
        croak('arguments undefined.');
    }
    my $pp = new();
    my $ii = $pp->loadImage($in);
    my $err = $pp->saveImage($out,$ii);
    $pp->releaseImage($ii);
    return $err;
}

sub preprocess {
    my ($in, $out) = @_;
    if ( !defined($in) || !defined($out) ) {
        croak('arguments undefined.');
    }
    my $pp = new();
    my $ii = $pp->loadImage($in);

    # TODO - All preprocessing steps

    my $err = $pp->saveImage($out,$ii);
    $pp->releaseImage($ii);
    return $err;
}

sub createImage {
    my ($self, $width, $height, $IPL_DEPTH, $Channel) = @_;
    if( !defined($width) || !defined($height) || !defined($IPL_DEPTH) || !defined($Channel) ){
        croak('arguments undefined.');
    }
    my $ret = $self->xs_createImage($width,$height,$IPL_DEPTH,$Channel);

    return $ret;
}

sub loadImage {
    my ($self, $filename) = @_;
    my $img = $self->xs_loadImage($filename);
}

sub saveImage {
    my ($self, $filename, $image) = @_;
    my $ret = $self->xs_saveImage($filename,$image);
}

sub releaseImage {
    my ($self,$image) = @_;
    if ( !defined($image) ) {
        croak('arguments undefined.');
    }
    $self->xs_releaseImage($image);
    return;
}

sub getWidth {
    my ($self,$image) = @_;
    if( !defined($image) ){
        croak('arguments undefined.');
    }
    my $ret = $self->xs_getWidth($image);
    return $ret;
}

sub getHeight {
    my ($self,$image) = @_;
    if( !defined($image) ){
        croak('arguments undefined.');
    }
    my $ret = $self->xs_getHeight($image);
    return $ret;
}

sub addBorder {
    my ($self,$image) = @_;
    if ( !defined($image) ) {
        croak('arguments undefined.');
    }
    my $ret = $self->xs_addBorder($image);
    return $ret;
}

sub split {
    my ($self,$image,$channels) = @_;
    if ( !defined($image) ) {
        croak('arguments undefined.');
    }
    $self->xs_split($image,$channels);
    return;
}

sub blur {
    my ($self,$image,$x,$y) = @_;
    if ( !defined($image) || !defined($x) || !defined($y) ) {
        croak('arguments undefined.');
    }
    my $ret = $self->xs_blur($image,$x,$y);
    return $ret;
}

sub convertToGray {
    my ($self,$image) = @_;
    if ( !defined($image) ) {
        croak('arguments undefined.');
    }
    my $ret = $self->xs_convertToGray($image);
    return $ret;
}

1;
