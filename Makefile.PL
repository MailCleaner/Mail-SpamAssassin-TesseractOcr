use 5.020002;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'Mail::SpamAssassin::Plugin::TesseractOcr',
    VERSION_FROM    => 'lib/Mail/SpamAssassin/Plugin/TesseractOcr.pm',
    PREREQ_PM       => {
        'Mail::SpamAssassin' => '3.004000',
        'Time::HiRes' => '1.9726',
        'POSIX' => '1.3803'
    },
    ABSTRACT_FROM   => 'lib/Mail/SpamAssassin/Plugin/TesseractOcr.pm',
    AUTHOR          => 'Fastnet SA - John Mertz <john.mertz@mailcleaner.net',
    LICENSE         => 'ASLv2'
);
