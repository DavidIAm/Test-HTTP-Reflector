package Test::HTTP::Reflector;

use warnings;
use strict;
use File::Path qw//;
use File::Spec::Functions;
use IO::Dir;
use Data::UUID;
use HTTP::Headers;
use HTTP::Response;

=head1 NAME

Test::HTTP::Reflector - Return stored posts as raw responses

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Sometimes, you're doing an integration test and you need to 
program a sequence of remote responses.  This class provides
the engine that allows a simple daemon program (as demonstrated
in the daemon.t test) to service such requests.

Feed back previously posted data to the client

 use Test::Integrate;
 use HTTP::Response;
 use HTTP::Headers;
 my $r = HTTP::Response->parse(Test::HTTP::Reflector->new( directory => '/aaa/', request => HTTP::Request->new(POST => '/set', {}, '404 NOT FOUND\nSpecial: DEFG\n\nABCD')));
 my $token = $r->headers->header('Token');
 my $rr = HTTP::Response->parse(Test::HTTP::Reflector->new( directory => '/aaa/', request => HTTP::Request->new(GET => '/'.$token)));
 is $rr->headers->header('Special'), 'DEFG'
 is $rr->content, 'ABCD'


=head1 SUBROUTINES/METHODS

=head2 new

constructor, takes a hash list.  Requires directory and request.

directory is the directory in which to store files while waiting for return requests.  
It will be created automatically and deleted even if it existed before, so be careful

request is the request object from the HTTP::Daemon connection.
 
=cut

sub new { 
  my $class = shift;
  my %args = @_;
  die "directory required" unless $args{directory};
  File::Path::mkpath $args{directory};
  die "Unable to create directory $args{directory} $?" unless -d $args{directory};
  die "request required" unless $args{request};
  return bless { %args }, $class;
}

=head2 directory

accessor.  returns the directory passed to the constructor.

=cut

sub directory {
  my $self = shift;
  return $self->{directory};
}

=head2 request

accessor.  returns the request object passed to the constructor.

=cut

sub request {
  my $self = shift;
  return $self->{request};
}

=head2 uuid

accessor.  returns the uuid object for uuid operations

=cut

sub uuid {
  my $self = shift;
  return $self->{uuid} if ($self->{uuid});
  $self->{uuid} = Data::UUID->new;
  return $self->{uuid};
}

=head2 response

operation.  distinguishes between a request for a text stream and
a command to store a text stream.  This is the entry point for this
module.  

Expected to return an HTTP reply text stream.

=cut

sub response {
  my $self = shift;
  my $path = $self->request->uri->path;
  my $possible_dir = catfile($self->directory, $path);
  if (-d $possible_dir) {
    return $self->retrieve($possible_dir);
  } else {
    return $self->store($possible_dir);
  }
}

=head2 retrieve

operation.  gets the content of a previously stored text stream and returns it.
Also rotates the directory down before returning.

=cut

sub retrieve {
  my $self = shift;
  my $path = shift;
  my $file = catfile($path, 1);
  die "No such file to retrieve ($file)" unless -f $file;
  my $buffer;
  my $data = '';
  my $fh = new IO::File $file;
  $data .= $buffer while read $fh, $buffer, 4028;
  $self->rotate_down($path);
  return $data;
}

=head2 rotate_down

operation.  rename all the files (which are numbered) down one number,
and delete the zero file.  Returns positive if the directory was 
removed, which requires all of the files to already be unlinked.

=cut

sub rotate_down {
  my $self = shift;
  my $dir = shift;
  my(@files, $file);

  # rename all the files down one number
  my $count = 0;
  while ( -e ($file = catfile($dir, $count+1))) {
    rename $file, catfile($dir, $count);
    $count ++;
  }

  # remove first file
  unlink catfile($dir, 0); 

  # clean up the directories.  This'll fail if there are any files still in it, which is okay.
  rmdir $dir;
  return rmdir $self->directory;
}

=head2 store

operation.  Store the indicated text stream on disk.  Creates a UUID for set commands.
Returns an HTTP success response with a Token header.

If the request doesn't make sense, it delegates it to the retrieve function

=cut

sub store {
  my $self = shift;
  my $possible_dir = shift;
  return $self->retrieve($possible_dir) unless $self->request->method eq 'POST'; # other verb?  Can't be a store.
  my $id;
  if ($self->request->uri->path =~ /^\/set/) {
    $id = $self->uuid->to_string($self->uuid->create());
  } elsif ($self->request->uri->path =~ /^\/add/) {
    ($id) = $self->request->uri->path =~ /^\/add\/(.+)$/;
    die "Unable to parse id out of add url" unless $id;
  } elsif ($self->request->uri->path =~ /^\/clear/) {
    ($id) = $self->request->uri->path =~ /^\/clear\/(.+)$/;
    die "Unable to parse id out of clear url" unless $id;
    do {} until $self->rotate_down($path);
    return;
  } else {
    return $self->retrieve($possible_dir); # Retrieve takes care of 404 type errors.
  }
  die "don't have an id. ($id)" unless $id;
  $self->store_by_id($id);
  my $headers = HTTP::Headers->new;
  $headers->header( Token => $id );
  return HTTP::Response->new( 200, 'Stored', $headers )->as_string;
}

=head2 store_by_id

operation.  Store the indicated text stream on disk in a directory named
for the id provided.

=cut

sub store_by_id {
  my $self = shift;
  my $id = shift;
  my $datdirectory = catdir($self->directory, $id);
  File::Path::mkpath $datdirectory;
  die "Unable to create directory $datdirectory $?" unless -d $datdirectory;
  my $file;
  my $count = 1;
  do {
    $file = catfile($datdirectory, $count ++);
  } until (! -e $file);
  my $ofile = IO::File->new($file, 'w');
  die "Unable to open file $file" unless $ofile;
  $ofile->print( $self->request->content ); 
  $ofile->close;
}

=head1 AUTHOR

David Ihnen, C<< <davidihnen at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-http-reflector at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-HTTP-Reflector>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::HTTP::Reflector


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-HTTP-Reflector>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-HTTP-Reflector>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-HTTP-Reflector>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-HTTP-Reflector/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 David Ihnen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Test::HTTP::Reflector

