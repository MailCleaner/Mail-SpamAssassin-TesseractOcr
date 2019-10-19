use 5.020002;
use strict;
use warnings;
use ExtUtils::MakeMaker;

link("lib/Mail/SpamAssassin/Plugin/TesseractOcr/Preprocess.xs", "Preprocess.xs");
chomp(my $libs    = `pkg-config opencv --libs`);
chomp(my $ccflags = `pkg-config opencv --cflags`);
die "cannot find opencv library." unless $libs;
$ccflags .= '-Isrc '.$ccflags;
WriteMakefile(
    NAME            => 'Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess',
    VERSION_FROM    => 'lib/Mail/SpamAssassin/Plugin/TesseractOcr.pm',
    PREREQ_PM       => {},
    #PREREQ_PM       => {
    #'Mail::SpamAssassin'    => '3.004000',
    #'Time::HiRes'           => '1.9726',
    #'POSIX'                 => '1.3803'
    #},
    ABSTRACT_FROM   => 'lib/Mail/SpamAssassin/Plugin/TesseractOcr.pm',
    AUTHOR          => 'Fastnet SA - John Mertz <john.mertz@mailcleaner.net>',
    LICENSE         => 'ASLv2',
    PL_FILES        => {},
    PMLIBDIRS       => [ 'lib' ],
    LIBS            => $libs,
    CCFLAGS         => $ccflags,
    TYPEMAPS        => ['types.map'],
    dist            => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
