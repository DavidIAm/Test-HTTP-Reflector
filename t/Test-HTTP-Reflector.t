#!perl

use Test::More tests => 12;
use Test::Exception;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Request;
use Test::HTTP::Reflector 'Integrate.pm';
use URI;

my $dir = '/tmp/testintegrates';

my $r;
lives_ok { $r = HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new
      ( POST => '/set'
      , HTTP::Headers->new
      , "404 NOT FOUND\nSpecial: DEFG\n\nABCD"
      )
    )->response
  ); };
my $token = $r->headers->header('Token');
note "Token is $token";

lives_ok { HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new
      ( POST => URI->new($r->headers->header('Add'))->path
      , HTTP::Headers->new
      , "401 NOT AUTHED\nSpecial: XYZ\n\nNOTHIN" 
      )
    )->response
  ); };

my $rr;
lives_ok { $rr = HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new(GET => URI->new($r->headers->header('Get'))->path)
    )->response
  ); };
lives_and sub { is $rr->headers->header('Special'), 'DEFG', 'first header' };
lives_and sub { is $rr->content, 'ABCD', 'first content' };

my $rs;
lives_ok { $rs = HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new(GET => URI->new($r->headers->header('Get'))->path)
    )->response
  ); };
lives_and sub { is $rs->headers->header('Special'), 'XYZ', 'second header' };
lives_and sub { is $rs->content, 'NOTHIN', 'second content' };

throws_ok { HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new(GET => URI->new($r->headers->header('Get'))->path)
    )->response
  ) } qr/No such file/, 'throw when we get too many';

my $rc;
lives_ok { $rc = HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new
      ( POST => '/set'
      , HTTP::Headers->new
      , "200 OK\n\nXYZ"
      )
    )->response
  ); };

lives_ok { HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new(GET => URI->new($rc->headers->header('Clear'))->path)
    )->response
  ); };

throws_ok { HTTP::Response->parse
  ( Test::HTTP::Reflector->new
    ( directory => $dir
    , request => HTTP::Request->new(GET => URI->new($rc->headers->header('Get'))->path)
    )->response
  ) } qr/No such file/, 'throw when we get the cleared';



system 'rm -r /tmp/integratetest';

