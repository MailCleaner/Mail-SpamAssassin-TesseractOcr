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

# TesseractOcr plugin, version 1.1.0
#
# Copyright 2019 - Fastnet SA
# Written by John Mertz (john.mertz@mailcleaner.net)

=head1 NAME

Mail::SpamAssassin::Plugin::TesseractOcr - Optical Character Recognition

=head1 VERSION

Version 1.1.0

=head1 SYNOPSIS

Install from CPAN with:

  cpan Mail::SpamAssassin::Plugin::TesseractOcr

Enable in your SpamAssassin config:

  loadplugin Mail::SpamAssassin::Plugin::TesseractOcr

Override default settings:

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

our $VERSION = '1.1.0';

package Mail::SpamAssassin::Plugin::TesseractOcr;

use strict;
use warnings;

use POSIX qw( strftime );
use Time::HiRes qw( gettimeofday tv_interval );
use Mail::SpamAssassin;
use Mail::SpamAssassin::Logger;
use Mail::SpamAssassin::Util;
use Mail::SpamAssassin::Timeout;
use Mail::SpamAssassin::Message::Node qw( find_parts );
use Mail::SpamAssassin::Plugin::TesseractOcr::Preprocessing qw( convert preprocess );

use vars qw(@ISA);
@ISA = qw(Mail::SpamAssassin::Plugin);

our $initialized = 0;
our ($tmpfile, $tmpdir);

# Verify non-perl dependencies
our $TESSERACT = Mail::SpamAssassin::Util::find_executable_in_env_path('tesseract') or die "Could not find 'tesseract' executable. You may need to install this package.\n";

sub new {
    my $class = shift;
    my $mailsa = shift;

    my $date = strftime "%Y-%m-%d %H:%M", localtime;
    dbg("TessaractOcr: Initiated Plugin $date");

    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsa);
    bless($self, $class);

    $self->set_config($mailsa->{conf});

    return $self;
}

sub set_config {
    my ($self, $conf) = @_;
    my @cmds;

=head1 USER OPTIONS

=item tocr_enabled (0|1)                        (default: 1)

Whether to use TesseractOcr, if it is available.

=cut

    push (@cmds, {
        setting => 'tocr_enable',
        default => 1,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

=item tocr_preprocess (0|1)                     (default: 1)

Whether to do image preprocessing to improve accuracy, or just convert to TIFF

=cut

    push (@cmds, {
        setting => 'tocr_preprocess',
        default => 1,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

=item tocr_msg_timeout                          (default: 15)

Timeout duration for an entire message.

=cut

    push (@cmds, {
        setting => 'tocr_msg_timeout',
        default => 15,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_img_timeout                          (default: 5)

Timeout duration for a single image. Used once when converting the
image and once when scanning the image.

=cut

    push (@cmds, {
        setting => 'tocr_img_timeout',
        default => 5,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_skip_(jpg|png|gif|bmp|tif|pdf)       (default: 0)

Disable scanning of individual image types.

=cut

    push (@cmds, {
        setting => 'tocr_skip_jpg',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

    push (@cmds, {
        setting => 'tocr_skip_png',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

    push (@cmds, {
        setting => 'tocr_skip_gif',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

    push (@cmds, {
        setting => 'tocr_skip_bmp',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

    push (@cmds, {
        setting => 'tocr_skip_tif',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

    push (@cmds, {
        setting => 'tocr_skip_pdf',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_BOOL
    });

=item tocr_min_size                             (default: 1024)

Minimum image size (bytes). Small images are unlikely to contain
OCR-friendly text

=cut

    push (@cmds, {
        setting => 'tocr_min_size',
        default => 1024,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_max_size                             (default: 4096000)

Maximum image size (bytes). Large images can take a long time to
OCR and are also somewhat less likely to contain text.

=cut

    push (@cmds, {
        setting => 'tocr_max_size',
        default => 4096000,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_min_(x|y)                            (default: 16)

Minimum height or width of an image (pixels). Narrow  images are
unlikely to contain OCR-friendly text.

=cut

    push (@cmds, {
        setting => 'tocr_min_x',
        default => 16,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

    push (@cmds, {
        setting => 'tocr_min_y',
        default => 16,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_max_(x|y)                            (default: 2048)

Maximum image heigh or width (pixels). Large images can take a long
time to OCR and are also somewhat less likely to contain text.

=cut

    push (@cmds, {
        setting => 'tocr_max_x',
        default => 2048,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

    push (@cmds, {
        setting => 'tocr_max_y',
        default => 2048,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_min_area                             (default: 512)

Minimum image area (pixels). Small images are unlikely to contain
OCR-friendly text.

=cut

    push (@cmds, {
        setting => 'tocr_min_area',
        default => 512,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

=item tocr_max_area                             (default: 2073600)

Maximum image area (pixels). Large images can take a long time to
OCR and are also somewhat less likely to contain text.

=cut

    push (@cmds, {
        setting => 'tocr_max_area',
        default => 2073600,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
    });

    $conf->{parser}->register_commands(\@cmds);
}

sub post_message_parse {
    my ($self, $pms) = @_;

    unless ($self->{main}->{conf}->{tocr_enable}) {
        dbg("TesseractOcr: not enabled");
        return 0;
    }

    # Setup a timeout
    my $end;
    my $begin = [gettimeofday];
    my $t = Mail::SpamAssassin::Timeout->new({ secs => $self->{main}->{conf}->{tocr_msg_timeout} });

    # Execute within that timeout
    $t->run(sub {
        $end = tesseract_do($self, $pms);
    });

    # Handle timout
    if ($t->timed_out()) {
        dbg("TesseractOcr: Scan timed out");
        my ($ret, $pid) = kill_pid();
        clean_up();
        if ($ret > 0) {
            dbg("TesseractOcr: Successfully killed PID $pid");
        } elsif ($ret < 0) {
            dbg("TesseractOcr: No processes left... exiting");
        } else {
            dbg("TesseractOcr: Failed to kill PID $pid, stale process!");
        }
        return 0;
    }

    # Report scantime
    my $duration = tv_interval($begin, [gettimeofday]);
    dbg("TesseractOcr: Completed in $duration seconds.");

    return $end;
}

sub tesseract_do {
    my ($self, $pms) = @_;
    my $msg = $pms->{'message'};

    Mail::SpamAssassin::PerMsgStatus::enter_helper_run_mode($self);

    dbg("TesseractOcr: Searching for images in messages.");
    my @types = (
        qr(^image\b)i,
        qr(^Application/Octet-Stream)i,
        qr(application/pdf)i
    );

    my $name_counter = 0;
    foreach my $type ( @types ) {
        foreach my $p ( $msg->find_parts($type) ) {
            my $fname = $p->{'name'};
            dbg("TesseractOcr: Found $fname of type $p->{'type'} matching image pattern $type.");

            my $d = $p->decode();
            my $ext;
            unless ( $ext = tesseract_type($self, $d) ) {
                dbg("TesseractOcr: Skipping $p->{'name'}: Unrecognized file format");
                next;
            }

            if ( my $skip = tesseract_skip($self, $d, $ext) ) {
                dbg("TesseractOcr: Skipping $p->{'name'}: $skip");
                next;
            }

            # Get a unique path
            $tmpfile = "$name_counter.$ext";
            $name_counter++;
            $tmpdir = Mail::SpamAssassin::Util::secure_tmpdir() or return 0;
            my $fullpath = Mail::SpamAssassin::Util::untaint_file_path(File::Spec->catfile($tmpdir, $tmpfile));
            dbg("TesseractOcr: Storing $p->{'name'} to $fullpath for scanning.");

            # Save tmp file
            unless (open PICT, ">$fullpath") {
                dbg("TesseractOcr: Cannot open $fullpath for writing.");
                clean_up();
                next;
            }
            binmode PICT;
            print PICT $d or dbg("TesseractOcr: Cannot write $fullpath: $!");
            close PICT;

            # Prepare image for scanning
            Mail::SpamAssassin::PerMsgStatus::enter_helper_run_mode($self);
            my $timer = Mail::SpamAssassin::Timeout->new( { secs => $self->{main}->{conf}->{tocr_img_timeout} } );
            my $out;
            my $err;

            # If Preprocessing is enabled, do so
            if ($self->{main}->{conf}->{tocr_preprocess}) {
                $out = "$fullpath-pp.tif";
                dbg("TesseractOcr: Preprocessing $fullpath; storing result as $out");
                $err = $timer->run_and_catch(Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess::preprocess($fullpath,$out);

            # If Preprocessing is NOT enabled, just convert it to TIF
            } else {
                # Skip if it is already a TIF
                if ($ext =~ 'tif') {
                    dbg("TesseractOcr: Image is already a tif, not converting");
                } else {
                    # CONVERT
                    $out = "$fullpath-cv.tif";

                    dbg("TesseractOcr: Converting $fullpath to $out");
                    $err = $timer->run_and_catch(Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess::convert($fullpath,$out);
=pod
                    $tmpfile .= ".tif";
                    # OLD METHOD: Converting with ImageMagick
                    my @args = ( $fullpath, '-compress','none','+matte', $out );

                    Mail::SpamAssassin::PerMsgStatus::enter_helper_run_mode();
                    my $pid;
                    my ($line,$inbuf);
                    $err = $timer->run_and_catch(sub {
                        $pid = Mail::SpamAssassin::Util::helper_app_pipe_open(*CONVERT, undef, 1, $CONVERT, @args);
                        if (!defined $pid) {
                            return "Failed to open pipe for convert command";
                        } else {
                            while ($line = read(CONVERT,$inbuf,8192)) {
                                dbg("TesseractOcr: CONVERT DEBUG $line");
                            }
                            unless (defined $line) {
                                return "TesseractOcr: Error reading from pipe: $!";
                            }

                            my $errno = 0;
                            close CONVERT or $errno = $!;
                            if (Mail::SpamAssassin::Util::proc_status_ok($?,$errno)) {
                                dbg("TesseractOcr: convert pid $pid finished successfully.");
                                return 1;
                            } elsif (Mail::SpamAssassin::Util::proc_status_ok($?,$errno,0,1)) {
                                dbg("TesseractOcr: convert pid $pid finished: " . Mail::SpamAssassin::Util::exit_status_str($?,$errno));
                                return 1;
                            } else {
                                dbg("TesseractOcr: convert pid $pid failed: " . Mail::SpamAssassin::Util::exit_status_str($?,$errno));
                                return 0;
                            }
                        }
                    });
                    Mail::SpamAssassin::PerMsgStatus::leave_helper_run_mode($self);
=end
                }
            }

            if ($err) {
                dbg("TessoractOcr: Failed to convert/process $out: $_");
                dbg("TessoractOcr: Removing unconverted file $fullpath");
                unlink $fullpath or dbg("TesseractOcr: Failed to remove $fullpath after failed conversion: $!");
                next;
            } elsif (! $ext =~ 'tif') {
                dbg("TessoractOcr: Successfully converted/processed $out");
                dbg("TessoractOcr: Removing unconverted file $fullpath");
                unlink $fullpath or dbg("TesseractOcr: Failed to remove $fullpath after conversion: $!");
                $fullpath = $out;
            }

            # Scan TIF and render results
            my ($pid, $content);
            my @args = ( $fullpath, 'stdout' );
            my $err = $timer->run_and_catch(sub {
                my ($inbuf, $line);
                $content = '';
                $pid = Mail::SpamAssassin::Util::helper_app_pipe_open(*TESSERACT, undef, 1, $TESSERACT, @args);
                if (!defined $pid) {
                    return "Failed to open pipe for tesseract command";
                } else {
                    while ($line = read(TESSERACT,$inbuf,8192)) {
                        $content .= $inbuf;
                    }
                    unless (defined $line) {
                        return "TesseractOcr: Error reading from pipe: $!";
                    }

                    if ($content eq '') {
                        dbg("TesseractOcr: No content discovered");
                    }

                    my $errno = 0;
                    close TESSERACT or $errno = $!;
                    if (Mail::SpamAssassin::Util::proc_status_ok($?,$errno)) {
                        dbg("TesseractOcr: tesseract pid $pid finished successfully.");
                    } elsif (Mail::SpamAssassin::Util::proc_status_ok($?,$errno,0,1)) {
                        dbg("TesseractOcr: tesseract pid $pid finished: " . Mail::SpamAssassin::Util::exit_status_str($?,$errno));
                    } else {
                        dbg("TesseractOcr: tesseract pid $pid failed: " . Mail::SpamAssassin::Util::exit_status_str($?,$errno));
                    }
                }
                });
            Mail::SpamAssassin::PerMsgStatus::leave_helper_run_mode($self);
            if ($timer->timed_out()) {
                dbg("TesseractOcr: Per image timeout reached for $tmpfile");
                cleanup();
                next;
            }

            if ($content) {
                $p->set_rendered($content);
                dbg("TesseractOcr: Found content: $content");
            } else {
                dbg("TesseractOcr: No text found.");
            }

            # Clean up
            dbg("TesseractOcr: Cleaning up temporary file: $fullpath");
            clean_up();

        }
    }

    return 1;
}

sub tesseract_type {
    my ($self, $d) = @_;

    if ( substr($d,0,3) eq "\x47\x49\x46" ) {
        return 'gif';
    } elsif ( substr($d,0,2) eq "\xff\xd8" ) {
        return 'jpg';
    } elsif ( substr($d,0,4) eq "\x89\x50\x4e\x47" ) {
        return 'png';
    } elsif ( substr($d,0,2) eq "BM" ) {
        return 'bmp';
    } elsif (
        (substr($d,0,4) eq "\x4d\x4d\x00\x2a") ||
        (substr($d,0,4) eq "\x49\x49\x2a\x00")
            ) {
        return 'tif';
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
    if ($size < $self->{main}->{conf}->{tocr_min_size}) {
        return "Image filesize too small. $size < $self->{main}->{conf}->{'tocr_min_size'}";
    } elsif ($size > $self->{main}->{conf}->{tocr_max_size}) {
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
            return "Cannot determine geometry of JPG.";
        } else {
            ($h,$w) = unpack("nn",substr($d,$pos+3,4));
        }
    } elsif ( $ext eq 'png' ) {
        ($w, $h) = unpack("NN",substr($d,16,8));
    } elsif ( $ext eq 'bmp' ) {
        ($w, $h) = unpack("VV",substr($d,18,8));
    } elsif ( $ext eq 'tif' ) {
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
            return "Cannot determine geometry of TIF.";
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

sub clean_up {
    if (defined $tmpfile) {
        my $fullpath = Mail::SpamAssassin::Util::untaint_file_path(File::Spec->catfile($tmpdir, $tmpfile));
        dbg("TesseractOcr: Removing $fullpath");
        if (-e $fullpath) {
            unlink $fullpath or dbg("TesseractOcr: Failed to remove $tmpfile: $!");
        }
        $tmpfile = undef;
    }
    if (defined $tmpdir) {
        if (-e $tmpdir) {
            dbg("TesseractOcr: Removing $tmpdir");
            rmdir $tmpdir or dbg("TesseractOcr: Failed to remove $tmpdir: $!");
        }
        $tmpdir = undef;
    }
}

1;
