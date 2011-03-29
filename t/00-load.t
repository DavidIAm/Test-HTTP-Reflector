#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Test::REST::Integrate' ) || print "Bail out!
";
}

diag( "Testing Test::REST::Integrate $Test::REST::Integrate::VERSION, Perl $], $^X" );
