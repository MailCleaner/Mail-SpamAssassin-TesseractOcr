# Mail::SpamAssassin::Plugin::TesseractOcr

Optical Character Recognition Plugin for SpamAssasin

## VERSION

4.00

### Important

The master branch work with Tesseract versions 4. If you are on an older distributions (specifically Debian Jessie). Checkout `3.00` for systems with Tesseract 3.X.

## SYNOPSIS

Enable in your SpamAssassin config:

    loadplugin Mail::SpamAssassin::Plugin::TesseractOcr

Override default settings:

    ifplugin Mail::SpamAssassin::Plugin::TesseractOcr
        tocr_setting_name   value
    endif

## DESCRIPTION

This plugin parses text from images within the body of an email and
passes any content found back to the parent SpamAssassin process.
This allows for the content to be tested against standard SpamAssasin
rules.

## DEPENDENCIES

### Run dependencies

tesseract-ocr => 4.00
opencv-dev => 2.00
spamassassin => 3.4.0
Time::HiRes => '1.9726'
POSIX => '1.3803'

Debian:
    sudo apt-get install tesseract-ocr libopencv-dev	// Time::HiRes and POSIX are included with Perl

### Build dependencies

pkg-config >= 0.28

Debian:
    sudo apt-get install pkg-config

## BUILD AND INSTALL

    git clone https://github.com/MailCleaner/TesseractOcr.git
    cd TesseractOcr
    perl Makefile.PL INSTALLSITEARCH=/proper/path/of/your/perl/libraries
    make
    sudo make install

## MANUAL TEST

   spamassassin --siteconfigpath=/conf/dir/which/includes/TesseractOcr.cf/ -t --debug TesseractOcr < example_email.eml

## OPTIONS

    tocr_enabled (0|1)

Whether to use TesseractOcr, if it is available.

    tocr_preprocess (0|1)

Whether to do image preprocessing to improve accuracy, or just convert to TIF.

    tocr_data_dir (string)

Tessdata language training directory ("--tessdata-dir <path>" option).

    tocr_langs (string)

Language data to use ("-l <lang>" option).

    tocr_msg_timeout (int)

Timeout duration for an entire message.

    tocr_img_timeout (int)

Timeout duration for a single image. Used once when converting the image and once when scanning the image.

    tocr_skip_(jpg|png|gif|bmp|tif|pdf) (0|1)

Disable scanning of individual image types.

    tocr_(min|max)_size (int)

Image size limit (bytes).

    tocr_(min|max)_(x|y) (int)

Image height/width limit (pixels).

    tocr_(min|max)_area (int)

Image area (x*y) limit (pixels).

## AUTHOR

John Mertz <john.mertz at mailcleaner.net>

## COPYRIGHT & LICENSE

Copyright 2020 Fastnet SA

This program is released under the Apache Software License, Version 2.0
