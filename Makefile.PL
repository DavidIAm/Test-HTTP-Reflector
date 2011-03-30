use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::HTTP::Reflector',
    AUTHOR              => q{David Ihnen <davidihnen@gmail.com>},
    VERSION_FROM        => 'lib/Test/HTTP/Reflector.pm',
    ABSTRACT_FROM       => 'lib/Test/HTTP/Reflector.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-HTTP-Reflector-*' },
);
