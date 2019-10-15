## Mail::SpamAssassin::Plugin::TesseractOcr

Optical Character Recognition Plugin for SpamAssasin

Version 1.1.0\-RC1

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

## AUTHOR

John Mertz <john.mertz at mailcleaner.net>

## COPYRIGHT & LICENSE

Copyright 2019 Fastnet SA

This program is released under the Apache Software License, Version 2.0

## USER OPTIONS

	tocr_enabled (0|1)                      (default: 1)

Whether to use TesseractOcr, if it is available.

	tocr_preprocess (0|1)                   (default: 1)

Whether to do image preprocessing to improve accuracy, or just convert to TIF

	tocr_msg_timeout                        (default: 15)

Timeout duration for an entire message.

	tocr_img_timeout                        (default: 5)

Timeout duration for a single image. Used once when converting the image and once when scanning the image.

	tocr_skip_(jpg|png|gif|bmp|tif|pdf)     (default: 0)

Disable scanning of individual image types.

	tocr_min_size                           (default: 1024)

Minimum image size (bytes). Small images are unlikely to contain OCR-friendly text

	tocr_max_size                           (default: 4096000)

Maximum image size (bytes). Large images can take a long time to OCR and are also somewhat less likely to contain text.

	tocr_min(x|y)                           (default: 16)

Minimum height or width of an image (pixels). Narrow  images are unlikely to contain OCR-friendly text.

	tocr_max_(x|y)                          (default: 2048)

Maximum image heigh or width (pixels). Large images can take a long time to OCR and are also somewhat less likely to contain text.

	tocr_min_area                           (default: 512)

Minimum image area (pixels). Small images are unlikely to contain OCR-friendly text.

	tocr_max_area                           (default: 2073600)

Maximum image area (pixels). Large images can take a long time to OCR and are also somewhat less likely to contain text.
