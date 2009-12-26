
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'WebService::TypePad',
    VERSION_FROM => 'lib/WebService/TypePad.pm',
    AUTHOR => 'Martin Atkins <matkins@sixapart.com>',
    PREREQ_PM => {
        LWP::UserAgent => 0,
        LWP::Parallel::UserAgent => 0,
        URI => 0,
        JSON::Any => 1.17,
        HTTP::Request => 0,
        HTTP::Request::Multi => 0,
    },
);

