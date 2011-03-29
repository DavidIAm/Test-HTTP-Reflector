#!perl 

use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;
use Test::Most tests => 7;
use Carp::Always;
use Test::REST::Integrate;

my $ua = new LWP::UserAgent;
my ($port, $pid) = daemon('./Test-REST-Integrate-Data');

END {
  kill 9, $pid;
}

my $token;
my $content;
my $url;
my $response;


$content = "200 OK
Header: Set like this
Content-type: text/plain
Content-length: 20

12345678901234567890
";

ok +$response = $ua->request( HTTP::Request->new(POST => 'http://localhost:'.$port.'/set/', HTTP::Headers->new, $content ) ), 'got response';

ok +$token = $response->header('token'), 'got token';

$url ='http://localhost:'.$port.'/'.$token;

ok +$ua->get($url)->header('Header'), 'Set like this';


$content = "200 OK
Header: Set like this
Content-type: text/plain
Content-length: 20

12345678901234567890
";
ok +$token = $ua->request( HTTP::Request->new(POST => 'http://localhost:'.$port.'/set/', HTTP::Headers->new, $content ) )->header('Token'), 'got token';
$url ='http://localhost:'.$port.'/'.$token;

$content = HTTP::Response->new( 404 => 'NOT FOUND', HTTP::Headers->new( 'Content-type' => 'text-plain', 'Content-length' => 9 , 'Not Found') )->as_string;

my $r = $ua->request
  ( HTTP::Request->new
    ( POST => 'http://localhost:'.$port.'/add/'.$token
    , HTTP::Headers->new()
    , $content 
    ) 
  );
  
ok $r->is_success, 'add returns success';

is +$ua->get($url)->status_line, '200 OK', 'first response';
is +$ua->get($url)->status_line, '404 NOT FOUND', 'second response';


sub daemon {
    my $directory = shift;

    use HTTP::Daemon;
    use HTTP::Status;
    use Getopt::Long;
    use File::Path;
    use English;

    mkpath $directory;
    die "Unable to create directory ($directory) $?" unless -d $directory;

    my $d = HTTP::Daemon->new( );
    die "Unable to listen $@ $? $!" unless $d;

    if (my $pid = fork) {
        return ($d->sockport, $pid);
    }
    while (my $c = $d->accept) {
        while (my $r = $c->get_request) {
            eval { $c->send_response(Test::REST::Integrate->new( directory => $directory, request => $r)->response); };
            if ($EVAL_ERROR) {
                $c->send_error(RC_FORBIDDEN, $EVAL_ERROR)
            }
        }
        $c->close;
        undef($c);
    }

}

