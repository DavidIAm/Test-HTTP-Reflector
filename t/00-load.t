#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Test::HTTP::Reflector' ) || print "Bail out!
";
}

diag( "Testing Test::HTTP::Reflector $Test::HTTP::Reflector::VERSION, Perl $], $^X" );
