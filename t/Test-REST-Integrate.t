#!perl

use Test::Most tests => 5;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Request;
use Test::REST::Integrate 'Integrate.pm';


my $r = HTTP::Response->parse
  ( Test::REST::Integrate->new
    ( directory => '/tmp/integratetest'
    , request => HTTP::Request->new
      ( POST => '/set'
      , HTTP::Headers->new
      , "404 NOT FOUND\nSpecial: DEFG\n\nABCD"
      )
    )->response
  );
my $token = $r->headers->header('Token');
note "Token is $token";

my $ra = HTTP::Response->parse
  ( Test::REST::Integrate->new
    ( directory => '/tmp/integratetest'
    , request => HTTP::Request->new
      ( POST => '/add/'.$token
      , HTTP::Headers->new
      , "401 DENIED\nSpecial: XYZ\n\nNOTHIN"
      )
    )->response
  );

my $rr = HTTP::Response->parse
  ( Test::REST::Integrate->new
    ( directory => '/tmp/integratetest'
    , request => HTTP::Request->new(GET => '/'.$token)
    )->response
  );
is $rr->headers->header('Special'), 'DEFG', 'first header';
is $rr->content, 'ABCD', 'first content';

my $rs = HTTP::Response->parse
  ( Test::REST::Integrate->new
    ( directory => '/tmp/integratetest'
    , request => HTTP::Request->new(GET => '/'.$token)
    )->response
  );
is $rs->headers->header('Special'), 'XYZ', 'second header';
is $rs->content, 'NOTHIN', 'second content';

throws_ok { HTTP::Response->parse
  ( Test::REST::Integrate->new
    ( directory => '/tmp/integratetest'
    , request => HTTP::Request->new(GET => '/'.$token)
    )->response
  ) } qr/No such file/, 'throw when we get too many';

system 'rm -r /tmp/integratetest';

