# <@LICENSE>
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

# TesseractOcr plugin, version 1.0.0
#
# Copyright 2019 - Fastnet SA
# Written by John Mertz (john.mertz@mailcleaner.net)

=head1 NAME

Mail::SpamAssassin::Plugin::TesseractOcr - Optical Character Recognition

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Install from CPAN with:

  cpan Mail::SpamAssassin::Plugin::TesseractOcr

Enable in your SpamAssassin config:

  loadplugin Mail::SpamAssassin::Plugin::TesseractOcr

Override default settings (TesseractOcr.pm: line 106):

  ifplugin Mail::SpamAssassin::Plugin::TesseractOcr
    tocr_setting_name   value
  endif

=head1 DESCRIPTION

This plugin parses text from images within the body of an email and
passes any content found back to the parent SpamAssassin process.
This allows for the content to be tested against standard SpamAssasin
rules.

=head1 AUTHOR

John Mertz C<< <john.mertz at mailcleaner.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2019 Fastnet SA

This program is released under the Apache Software License, Version 2.0

=cut

our $VERSION = '1.0.0';

package Mail::SpamAssassin::Plugin::TesseractOcr;

use strict;
use warnings;

use POSIX qw(strftime);
use Time::HiRes qw( gettimeofday tv_interval );
use Mail::SpamAssassin;
use Mail::SpamAssassin::Logger;
use Mail::SpamAssassin::Util;
use Mail::SpamAssassin::Timeout;
use Mail::SpamAssassin::Message::Node qw(find_parts);
use Image::OCR::Tesseract;

use vars qw(@ISA);
@ISA = qw(Mail::SpamAssassin::Plugin);

our $initialized = 0;
our ($tmpfile, $tmpdir);

sub new {
    my $class = shift;
    my $mailsa = shift;

    my $date = strftime "%Y-%m-%d %H:%M", localtime;
    debuglog("Initiated TesseractOcr Plugin $date");

    # Verify non-perl dependencies
    use File::Which 'which';
    which('tesseract') || die "Could not find 'tesseract' executable. You may need to install this package.\n";
    which('convert') || die "Could not find 'convert' executable. You may need to install this package.\n";

    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsa);
    bless($self, $class);

    if (!$initialized) {
        # Default settings, in case not defined in TesseractOcr.cf
        my %defaults = (
            tocr_timeout => 15,
            tocr_skip_jpg => 0,
            tocr_skip_gif => 0,
            tocr_skip_bmp => 0,
            tocr_skip_png => 0,
            tocr_skip_tiff => 0,
            tocr_min_size => 1024,
            tocr_max_size => 4096000,
            tocr_min_x => 32,
            tocr_min_y => 32,
            tocr_min_area => 256,
            tocr_max_x => 2048,
            tocr_max_y => 2048,
            tocr_max_area => 2073600, #1920*1080
        );

        # Filling in missing settings
        foreach my $key (keys %defaults) {
            if (!defined $self->{main}->{conf}->{$key}) {
                $self->{main}->{conf}->{$key} = $defaults{$key};
                debuglog("$key is not defined in config file, using default value $self->{main}->{conf}->{$key}.");
            } else {
                debuglog("$key is defined as $self->{main}->{conf}->{$key} in config file.");
            }
        }

        $initialized = 1;
    }

    return $self;
}

sub debuglog {
    my $message = shift;
    Mail::SpamAssassin::Logger::log_message("debug",("TesseractOcr: $message"));
}

sub infolog {
    my $message = shift;
    Mail::SpamAssassin::Logger::log_message("info",("TesseractOcr: $message"));
}

sub parse_config {
    my ($self, $opts) = @_;

    if ($opts->{line} =~ m/^tocr_/) {
        $self->{main}->{conf}->{$opts->{line}} = $opts->{value};
        $self->inhibit_further_callbacks();
    } else {
        return 0;
    }

    return 1;
}

sub post_message_parse {
    my ($self, $pms) = @_;
    my $msg = $pms->{'message'};

    # Setup a timeout
    my $end;
    my $begin = [gettimeofday];
    my $t = Mail::SpamAssassin::Timeout->new({ secs => $self->{base}->{conf}->{tocr_timeout} });

    # Execute within that timeout
    $t->run(sub {
        $end = tesseract_do($self, $msg);
    });

    # Handle timout
    if ($t->timed_out()) {
        infolog("Tesseract scan timed out");
        my ($ret, $pid) = kill_pid();
        if (defined $tmpdir) {
            if (defined $tmpfile) {
                unlink $tmpfile;
                $tmpfile = undef;
            }
            rmdir $tmpdir;
            $tmpdir = undef;
        }
        if ($ret > 0) {
            debuglog("Successfully killed PID $pid");
        } elsif ($ret < 0) {
            debuglog("No processes left... exiting");
        } else {
            infolog("Failed to kill PID $pid, stale process!");
        }
        return 0;
    }

    # Report scantime
    my $duration = tv_interval($begin, [gettimeofday]);
    debuglog("Tesseract completed in $duration seconds.");

    return $end;
}

sub tesseract_do {
    my ($self, $msg ) = @_;

    debuglog("Searching for images in messages.");

    my @types = (
        qr(^image\b)i,
        qr(^Application/Octet-Stream)i,
        qr(application/pdf)i
    );

    my $unnamed = 0;

    foreach my $type ( @types ) {
        foreach my $p ( $msg->find_parts($type) ) {
            my ($fname, $ext);
            if (defined $p->{'name'}) {
                $fname = $p->{'name'};
            } else {
                $fname = "unnamed" . $unnamed++;
            }
            my $ctype = $p->{'type'};
            infolog("TesseractOcr found $fname of type $ctype matching image pattern $type.");

            my $d = $p->decode();
            unless ( $ext = tesseract_type($self, $d) ) {
                infolog("Skipping $fname: Unrecognized file format");
                next;
            }

            if ( my $skip = tesseract_skip($self, $d, $ext) ) {
                infolog("Skipping $fname: $skip");
                next;
            }

            infolog("Scanning $fname...");

            # Get a unique path
            $tmpdir = Mail::SpamAssassin::Util::secure_tmpdir() || return 0;
            my $fullpath = Mail::SpamAssassin::Util::untaint_file_path($tmpdir . "/" . $fname);
            my $unique = 0;
            while (-e $fullpath) {
                $fullpath = Mail::SpamAssassin::Util::untaint_file_path($tmpdir . "/" . chr(65+$unique++) . $fname);
            }
            debuglog("Storing $fname to $fullpath for scanning.");

            # Save tmp file
            unless (open PICT, ">$fullpath") {
                infolog("Cannot open $fullpath for writing.");
            }
            $tmpfile = $fname;
            binmode PICT;
            print PICT $d;
            close PICT;

            # Scan tmp file
            my $content = Image::OCR::Tesseract::get_ocr($fullpath);
            if ($content) {
                $p->set_rendered($content);
                debuglog("Found content: $content");
            } else {
                debuglog("No content discovered");
            }
            debuglog("Cleaning temporary file: $fullpath");
            unlink $fullpath;
            rmdir $tmpdir;
            $tmpfile = undef;
            $tmpdir = undef;

        }
    }

    return 1;
}

sub tesseract_type {
    my ($self, $d) = @_;

    my ($w, $h);
    if ( substr($d,0,3) eq "\x47\x49\x46" ) {
        return 'gif';
    } elsif ( substr($d,0,2) eq "\xff\xd8" ) {
        return 'jpg';
    } elsif ( substr($d,0,4) eq "\x89\x50\x4e\x47" ) {
        return 'png';
        ($w, $h) = unpack("NN",substr($d,16,8));
    } elsif ( substr($d,0,2) eq "BM" ) {
        return 'bmp';
        ($w, $h) = unpack("VV",substr($d,18,8));
    } elsif (
        (substr($d,0,4) eq "\x4d\x4d\x00\x2a") ||
        (substr($d,0,4) eq "\x49\x49\x2a\x00")
            ) {
        return 'tiff';
    } elsif ( substr($d,0,5) eq "\x25\x50\x44\x46\x2d" ) {
        return 'pdf';
    } else {
        return 0;
    }
}

sub tesseract_skip {
    my ($self, $d, $ext) = @_;
    my ($t, $w, $h) = ('', 0, 0);

    if ( $self->{main}->{conf}->{"tocr_skip_$ext"} ) {
        return "$ext extension is disabled in the config file."
    }

    my $size = length($d);
    if ($size <= $self->{main}->{conf}->{tocr_min_size}) {
        return "Image filesize too small. $size < $self->{main}->{conf}->{'tocr_min_size'}";
    } elsif ($size >= $self->{main}->{conf}->{tocr_max_size}) {
        return "Image filesize too large. $size > $self->{main}->{conf}->{'tocr_max_size'}";
    }

    if ( $ext eq 'gif' ) {
        ($w, $h) = unpack("vv",substr($d,6,4));
    } elsif ( $ext eq 'jpg' ) {
        my @Markers = (0xC0,0xC1,0xC2,0xC3,0xC5,0xC6,0xC7,0xC9,0xCA,0xCB,0xCD,0xCE,0xCF);
        my $pos = 2;
        while ($pos < $size) {
            my ($b,$m) = unpack("CC",substr($d,$pos,2));
            $pos += 2;
            if ($b != 0xff) {
            #my ($b != 0xff) {
                return "Invalid JPEG image.";
            }
            my $skip = 0;
            foreach my $mm (@Markers) {
                if ($mm == $m) {
                    $skip++;
                    last;
                }
            }
            if ($skip) {
                last;
            }
            $pos += unpack("n",substr($d,$pos,2));
        }
        if ($pos > $size) {
            return "Cannot determine geometry of JPEG.";
        } else {
            ($h,$w) = unpack("nn",substr($d,$pos+3,4));
        }
    } elsif ( $ext eq 'png' ) {
        ($w, $h) = unpack("NN",substr($d,16,8));
    } elsif ( $ext eq 'bmp' ) {
        ($w, $h) = unpack("VV",substr($d,18,8));
    } elsif ( $ext eq 'tiff' ) {
        my $worder = (substr($d,0,2) eq "\x4d\x4d") ? 0 : 1;
        my $offset = unpack($worder?"V":"N",substr($d,4,4));
        my $number = unpack($worder?"v":"n",substr($d,$offset,2)) - 1;
        foreach my $n (0 .. $number) {
            my $add = 2 + ($n * 12);
            my ($id,$tag,$cnt,$val) = unpack($worder?"vvVV":"nnNN",substr($d,$offset+$add,12));
            if ($id == 256) {
                $h = $val;
            } elsif ($id == 257) {
                $w = $val;
            } elsif ($h != 0 && $w != 0) {
                last;
            }
        }
        if ($h == 0 || $w == 0) {
            return "Cannot determine geometry of TIFF.";
        }
    } elsif ( $ext eq 'pdf' ) {
        # Geometry rules do not apply to PDF
        return 0;
    }

    if ( $w <= $self->{main}->{conf}->{'tocr_min_x'} ) {
        return "Below minimum width. $w < $self->{main}->{conf}->{'tocr_min_x'}";
    } elsif ( $w >= $self->{main}->{conf}->{'tocr_max_x'} ) {
        return "Above maximum width. $w > $self->{main}->{conf}->{'tocr_min_x'}";
    } elsif ( $h <= $self->{main}->{conf}->{'tocr_min_y'} ) {
        return "Below minimum height. $h < $self->{main}->{conf}->{'tocr_min_y'}";
    } elsif ( $h >= $self->{main}->{conf}->{'tocr_max_y'} ) {
        return "Above maximum height. $w > $self->{main}->{conf}->{'tocr_min_y'}";
    } elsif ( ($w * $h) <= $self->{main}->{conf}->{'tocr_min_area'} ) {
        return "Below minimum area. $w*$h < $self->{main}->{conf}->{'tocr_min_area'}";
    } elsif ( ($w * $h) >= $self->{main}->{conf}->{'tocr_max_area'} ) {
        return "Above maximum area. $w*$h > $self->{main}->{conf}->{'tocr_max_area'}";
    }

    return 0;
}

1;
