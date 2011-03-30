package Test::HTTP::Reflector;

use warnings;
use strict;
use File::Path qw//;
use File::Spec::Functions;
use IO::Dir;
use URI;
use Carp;
use Data::UUID;
use HTTP::Headers;
use HTTP::Response;

=head1 NAME

Test::HTTP::Reflector - Return stored posts as raw responses

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Sometimes, you're doing an integration test and you need to 
program a sequence of remote responses.  This class provides
the engine that allows a simple daemon program to service such 
requests.

This program feed back previously posted data to the client

 use Test::Integrate;
 use HTTP::Response;
 use HTTP::Headers;
 # http parse <- reflector response <- reflector request <- post content <- to_string <- Test HTTP response
 my $r = HTTP::Response->parse
   ( Test::HTTP::Reflector->new
     ( directory => '/aaa/'
     , request => HTTP::Request->new
       ( POST => '/set'
       , {} 
       , HTTP::Response->new
         ( 404 => 'NOT FOUND'
         , HTTP::Header->new('Special' => DEFG')
         , 'ABCD'
         )->as_string
       )
     )->response
   );
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
  croak "directory required" unless $args{directory};
  File::Path::mkpath $args{directory};
  croak "Unable to create directory $args{directory} $?" unless -d $args{directory};
  croak "request required" unless $args{request};
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
  if ($self->request->method eq 'POST') {
    return $self->store;
  }
  return $self->retrieve;
}

=head2 retrieve

operation.  gets the content of a previously stored text stream and returns it.
Also rotates the directory down before returning.

=cut

sub retrieve {
  my $self = shift;
  my $file = catfile($self->storage, 1);
  croak "No such file to retrieve ($file)" unless -f $file;
  my $buffer;
  my $data = '';
  my $fh = new IO::File $file;
  $data .= $buffer while read $fh, $buffer, 4028;
  $self->rotate_down;
  return $data;
}

=head2 rotate_down

operation.  rename all the files (which are numbered) down one number,
and delete the zero file.  Returns positive if the directory was 
removed, which requires all of the files to already be unlinked.

=cut

sub rotate_down {
  my $self = shift;
  my $dir = $self->storage;
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
  rmdir $dir unless -f catfile $dir, 1;
  rmdir $self->directory unless -d $dir;
  return not -d $dir;
}

=head2 id

accessor.  Get the id from the current request.

=cut

sub id {
  my $self =shift;
  return $self->{id} if $self->{id};
  ($self->{id}) = $self->request->uri->path =~ /\/([a-z0-9-]+)$/i;
  $self->{id} = $self->uuid->to_string($self->uuid->create()) unless $self->{id} and eval { $self->uuid->from_string($self->{id}); };
  return $self->{id};
}

=head2 store

operation.  Store the indicated text stream on disk.  Creates a UUID for set commands.
Returns an HTTP success response with a Token header.

If the request doesn't make sense, it delegates it to the retrieve function

=cut

sub store {
  my $self = shift;
  return $self->retrieve($self->storage) unless $self->request->method eq 'POST'; # other verb?  Can't be a store.
  if ($self->request->uri->path =~ /^\/set/) {
    $self->clear;
  }
  $self->store_in_file;
  my $headers = HTTP::Headers->new
    ( Token => $self->id
    , Get => $self->get_url
    , Add => $self->add_url
    , Clear => $self->clear_url
    );
  return HTTP::Response->new( 200, 'STORED', $headers )->as_string;
}

=head2 get_url

accessor. The url that you can use to get this token's data

=cut

sub get_url {
  my $self = shift;
  return URI->new_abs('/'.$self->id, $self->base_url);
}

=head2 add_url

accessor. The url that you can use to add to this token's data

=cut

sub add_url {
  my $self = shift;
  return URI->new_abs('/add/'.$self->id, $self->base_url);
}

=head2 clear_url

accessor. The url that you can use to clear to this token's data

=cut

sub clear_url {
  my $self = shift;
  return URI->new_abs('/clear/'.$self->id, $self->base_url);
}

=head2 base_url

accessor.  The base url for this resource.

=cut

sub base_url {
  my $self = shift;
  my $uri = URI->new_abs('/', $self->request->uri );
  $uri->scheme( 'http' );
  $uri->host( $self->request->header('host') );
  return $uri->clone;
}

=head2 storage

accessor.  The full file storage path for the current file

=cut

sub storage {
  my $self = shift;
  return catfile($self->directory, $self->id);
}

=head2 clear

operation.  delete all the entries for the token specified.

=cut

sub clear {
  my $self = shift;
  my $count = 0;
  do { last if $count ++ > 100000 } until $self->rotate_down($self->storage);
}

=head2 store_in_file

operation.  Store the indicated text stream on disk in a directory named
for the token

=cut

sub store_in_file {
  my $self = shift;
  my $datdirectory = $self->storage;
  File::Path::mkpath $datdirectory;
  croak "Unable to create directory $datdirectory $?" unless -d $datdirectory;
  my $file;
  my $count = 1;
  do {
    $file = catfile($datdirectory, $count ++);
  } while (-e $file);
  my $ofile = IO::File->new($file, 'w');
  croak "Unable to open file $file" unless $ofile;
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

