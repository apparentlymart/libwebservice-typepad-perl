
=head1 NAME

WebService::TypePad - Interface to the Six Apart TypePad API

=cut

package WebService::TypePad;

use 5.006;
use vars qw($VERSION);
$VERSION = '0.01';

use strict;
use warnings;
use Carp;
use WebService::TypePad::Request;
#use WebService::TypePad::List;

=head1 SYNOPSIS

    my $typepad = WebService::TypePad->new();
    my $req = $typepad->new_request();
    $req->add_task(user => $typepad->user('melody')->load_task());
    $req->add_task(memberships => $typepad->user('melody')->load_memberships_task());
    my $results = $req->run();
    my $user = $results->{user};
    my $memberships = $results->{memberships};

=head1 REQUEST MODEL

To reduce overhead, the TypePad API supports batch requests. This library is designed
around this concept, so requests are made by building up a batch request object
containing named tasks and then running the request to obtain a map of task name
to result.

=head1 METHODS

=head2 WebService::TypePad->new(%opts)

Create a new TypePad API client instance.

By default, with no arguments, the returned object will be configured to use
the API endpoints for the main TypePad service. However, the argument
C<backend_url> can be used to override this and have the
client connect to a different URL. For example:

    my $typepad = WebService::TypePad->new(
        backend_url => 'http://127.0.0.1/',
    );

If no arguments are supplied, the client will do unauthenticated requests to
the unauthenticated TypePad endpoints. To do authenticated requests, provide the
necessary OAuth parameters. For example:

    my $typepad = WebService::TypePad->new(
        consumer_key => '...',
        consumer_secret => '...',
        access_token => '...',
        access_token_secret => '...',
    );

If you need to obtain an access_token and access_token_secret, you can use
the methods provided by L<WebService::TypePad::Auth>.

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;

    foreach my $k (qw(backend_url)) {
        $self->{$k} = delete $opts{$k};
    }

    my $auth_args_count = 0;
    foreach my $k (qw(consumer_key consumer_secret access_token access_token_secret)) {
        $self->{$k} = delete $opts{$k};
        $auth_args_count++ if defined($self->{$k});
    }

    if ($auth_args_count == 4) {
        $self->{authenticated} = 1;
    }
    elsif ($auth_args_count == 0) {
        $self->{authenticated} = 0;
    }
    else {
        croak "Must provide all four OAuth arguments in order to use authenticated requests";
    }

    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    unless ($self->{backend_url}) {
        if ($self->authenticated) {
            $self->{backend_url} = 'https://api.typepad.com/';
        }
        else {
            $self->{backend_url} = 'http://api.typepad.com/';
        }
    }

    return $self;
}

sub backend_url {
    return $_[0]->{backend_url};
}

sub authenticated {
    return $_[0]->{authenticated};
}

sub new_request {
    my ($self) = @_;

    return WebService::TypePad::Request->new_for_api($self);
}

sub consumer_key {
    return $_[0]->{consumer_key};
}

sub consumer_secret {
    return $_[0]->{consumer_secret};
}

sub access_token {
    return $_[0]->{access_token};
}

sub access_token_secret {
    return $_[0]->{access_token_secret};
}

sub oauth_parameters {
    my ($self) = @_;

    return (
        token => $self->access_token,
        token_secret => $self->access_token_secret,
        consumer_key => $self->consumer_key,
        consumer_secret => $self->consumer_secret,
    );
}

1;

=head1 AUTHOR

Copyright 2009 Six Apart Ltd. All rights reserved.

=head1 LICENCE

This package may be distributed under the same terms as Perl itself.

