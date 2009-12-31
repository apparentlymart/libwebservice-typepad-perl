
=head1 NAME

WebService::TypePad - Interface to the Six Apart TypePad API

=cut

package WebService::TypePad;

use 5.006;
use vars qw($VERSION);
$VERSION = '0.01_01';

use strict;
use warnings;
use Carp;
use WebService::TypePad::Request;
use WebService::TypePad::Noun;
#use WebService::TypePad::List;

=head1 SYNOPSIS

    my $typepad = WebService::TypePad->new();
    my $user = $typepad->users->get_user(user_id => '6p1234123412341234');
    my $user_memberships = $typepad->users->get_user_memberships(user => $user);

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

=pod

=head2 Noun Accessors

Each noun in the TypePad API is represented in this library as a class.
An instance of a noun class can be obtained by calling the method
named after it on the typepad instance.

For example, to get the "users" noun, call C<< $typepad->users >>.
Dashes in the names are replaced with underscores to create valid Perl
method names.

A full list of nouns known to this version of the library is in
L<WebService::TypePad::Noun|WebService::TypePad::Noun>.

=cut

# Generate an accessor for each of the known nouns.
{

    foreach my $noun_accessor (keys %WebService::TypePad::Noun::Nouns) {
        my $class_name = $WebService::TypePad::Noun::Nouns{$noun_accessor};
        my $full_accessor_name = __PACKAGE__."::".$noun_accessor;

        my $accessor_func = sub {
            eval "use $class_name;";
            return $class_name->_new_for_client($_[0]);
        };

        {
            no strict 'refs';
            *{$full_accessor_name} = $accessor_func;
        }
    }

}

1;

=head1 AUTHOR

Copyright 2009 Six Apart Ltd. All rights reserved.

=head1 LICENCE

This package may be distributed under the same terms as Perl itself.

