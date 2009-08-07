package AnyEvent::HTTPD::Request;
use strict;
no warnings;

=head1 NAME

AnyEvent::HTTPD::Request - A web application request handle for L<AnyEvent::HTTPD>

=head1 DESCRIPTION

This is the request object as generated by L<AnyEvent::HTTPD> and given
in the request callbacks.

=head1 METHODS

=over 4

=cut

sub new {
   my $this  = shift;
   my $class = ref($this) || $this;
   my $self  = { @_ };
   bless $self, $class
}

=item B<url>

This method returns the URL of the current request.

=cut

sub url {
   my ($self) = @_;
   my $url = $self->{url};
   my $u = URI->new ($url);
   $u->query (undef);
   $u
}

=item B<respond ([$res])>

C<$res> can be:

=over 4

=item * an array reference

Then the array reference has these elements:

   my ($code, $message, $header_hash, $content) =
         [200, 'ok', { 'Content-Type' => 'text/html' }, '<h1>Test</h1>' }]

=item * a hash reference

If it was a hash reference the hash is first searched for the C<redirect>
key and if that key does not exist for the C<content> key.

The value for the C<redirect> key should contain the URL that you want to redirect
the request to.

The value for the C<content> key should contain an array reference with the first
value being the content type and the second the content.

=back

Here is an example:

   $httpd->reg_cb (
      '/image/elmex' => sub {
         my ($httpd, $req) = @_;

         open IMG, "$ENV{HOME}/media/images/elmex.png"
            or $req->respond (
                  [404, 'not found', { 'Content-Type' => 'text/plain' }, 'not found']
               );

         $req->respond ({ content => ['image/png', do { local $/; <IMG> }] });
      }
   );

B<How to send large files:>

For longer responses you can give a callback instead of a string to
the response function for the value of the C<$content>.

   $req->response ({ content => ['video/x-ms-asf', sub {
      my ($data_cb) = @_;

      # start some async retrieve operation, for example use
      # IO::AIO (with AnyEvent::AIO). Or retrieve chunks of data
      # to send somehow else.

   } });

The given callback will receive as first argument either another callback
(C<$data_cb> in the above example) or an undefined value, which means that
there is no more data required and the transfer has been completed (either by
you sending no more data, or by a disconnect of the client).

The callback given to C<response> will be called whenever the send queue of the
HTTP connection becomes empty (meaning that the data is written out to the
kernel). If it is called you have to start delivering the next chunk of data.

That doesn't have to be immediately, before the callback returns.  This means
that you can initiate for instance an L<IO::AIO> request (see also
L<AnyEvent::AIO>) and send the data later.  That is what the C<$data_cb>
callback is for. You have to call it once you got the next chunk of data. Once
you sent a chunk of data via C<$data_cb> you can just wait until your callback
is called again to deliver the next chunk.

If you are done transferring all data call the C<$data_cb> with an empty string
or with no argument at all.

Please consult the example script C<large_response_example> from the
C<samples/> directory of the L<AnyEvent::HTTPD> distribution for an example of
how to use this mechanism.

B<NOTE:> You should supply a 'Content-Length' header if you are going to send a
larger file. If you don't do that the client will have no chance to know if the
transfer was complete. To supply additional header fields the hash argument
format will not work. You should use the array argument format for this case.

=cut

sub respond {
   my ($self, $res) = @_;

   return unless $self->{resp};

   my $rescb = delete $self->{resp};

   if (ref $res eq 'HASH') {
      my $h = $res;
      if ($h->{redirect}) {
         $res = [
            301, 'redirected', { Location => $h->{redirect} },
            "Redirected to <a href=\"$h->{redirect}\">here</a>"
         ];
      } elsif ($h->{content}) {
         $res = [
            200, 'ok', { 'Content-Type' => $h->{content}->[0] },
            $h->{content}->[1]
         ];
      }

   }

   $self->{responded} = 1;

   if (not defined $res) {
      $rescb->(404, "ok", { 'Content-Type' => 'text/html' }, "<h1>No content</h1>");

   } else {
      $rescb->(@$res);
   }
}

=item B<responded>

Returns true if this request already has been responded to.

=cut

sub responded { $_[0]->{responded} }

=item B<parm ($key)>

Returns the first value of the form parameter C<$key> or undef.

=cut

sub parm {
   my ($self, $key) = @_;

   if (exists $self->{parm}->{$key}) {
      return $self->{parm}->{$key}->[0]->[0]
   }

   return undef;
}

=item B<params>

Returns list of parameter names.

=cut

sub params { keys %{$_[0]->{parm} || {}} }

=item B<vars>

Returns a hash of form parameters. The value is either the 
value of the parameter, and in case there are multiple values
present it will contain an array reference of values.

=cut

sub vars {
   my ($self) = @_;

   my $p = $self->{parm};

   my %v = map {
      my $k = $_;
      $k =>
         @{$p->{$k}} > 1
            ? [ map { $_->[0] } @{$p->{$k}} ]
            : $p->{$k}->[0]->[0]
   } keys %$p;

   %v
}

=item B<method>

This method returns the method of the current request.

=cut

sub method { $_[0]{method} }

=item B<content>

Returns the request content or undef if only parameters for a form
were transmitted.

=cut

sub content { $_[0]->{content} }

=item B<headers>

This method will return a hash reference containing the HTTP headers for this
HTTP request.

=cut

sub headers { $_[0]->{hdr} }

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
