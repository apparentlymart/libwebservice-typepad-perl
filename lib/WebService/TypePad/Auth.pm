
=head1 NAME

WebService::TypePad::Auth - Methods for provisioning API access tokens

=head1 DESCRIPTION

This package provides some utility methods for provisioning API access tokens
to allow your application to act on the behalf of a user.

This is actually just a wrapper around the provisioning steps in L<Net::OAuth>,
though it will auto-configure based on the proprietary OAuth discovery
functionality that the TypePad API offers.

=cut

package WebService::TypePad::Auth;

use strict;
use warnings;
use WebService::TypePad;
use Carp qw(croak);
use LWP::UserAgent;
use HTTP::Request;
use Net::OAuth;

=head1 METHODS

=cut

=pod

=head2 WebService::TypePad::Auth->new(%opts)

Create a new instance. Takes the same options as the constructor for
L<WebService::TypePad> except the OAuth access token and
its associated secret, which of course this instance will help
you to obtain.

=cut

# FIXME: This package kinda lives out on its own right now, not really making
# use of the rest of the client code. Should clean this up so there's less
# duplicate code at some point.

BEGIN {
    eval {  require Math::Random::MT };
    unless ($@) {
        Math::Random::MT->import(qw(srand rand));
    }
}

sub new {
    my ($class, %opts) = @_;

    my $consumer_key = delete $opts{consumer_key} or croak "consumer_key is required";
    my $consumer_secret = delete $opts{consumer_secret} or croak "consumer_secret is required";

    my $backend_url = delete $opts{backend_url};

    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    my $self = bless {}, $class;
    $self->{consumer_key} = $consumer_key;
    $self->{consumer_secret} = $consumer_secret;
    $self->{backend_url} = $backend_url;
    return $self;

}

sub request_token {
    my ($self, %opts) = @_;

    # First we ask the server what endpoints we should be using.
    my $application = $self->_application_object;

    my $request_token_link = $application->get_link_with_relationship('oauth-request-token-endpoint');

    my $request = Net::OAuth->request("request token")->new(
        consumer_key => $self->{consumer_key},
        consumer_secret => $self->{consumer_secret},
        request_url => $request_token_link->href,
        request_method => 'POST',
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->_nonce(),
    );

    $request->sign();

    my $ua = LWP::UserAgent->new();
    $ua->agent('WebService::TypePad/'.$WebService::TypePad::VERSION);

    my $req = HTTP::Request->new(POST => $request_token_link->href);
    $req->content_type("application/x-www-form-urlencoded");
    $req->content($request->to_post_body());

    my $res = $ua->request($req);

    croak "Failed to obtain request token" unless $res->is_success;

    my $response = Net::OAuth->response('request token')->from_post_body($res->content);

    my $request_token = $response->token;
    my $request_token_secret = $response->token_secret;

    return ($request_token, $request_token_secret);
}

sub authorization_url {
    my ($self, %opts) = @_;

    my $request_token = delete $opts{request_token} or die "request_token is required";
    my $request_token_secret = delete $opts{request_token_secret} or die "request_token_secret is required";
    my $callback_url = delete $opts{callback_url};
    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    my $application = $self->_application_object;
    my $authorization_link = $application->get_link_with_relationship('oauth-authorization-page');

    my $auth_request = Net::OAuth->request('user authentication')->new(
        token => $request_token,
        callback => $callback_url,
    );
    return $auth_request->to_url($authorization_link->href);

}

sub access_token {
    my ($self, %opts) = @_;

    my $request_token = delete $opts{request_token} or die "request_token is required";
    my $request_token_secret = delete $opts{request_token_secret} or die "request_token_secret is required";
    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    my $application = $self->_application_object;
    my $access_token_link = $application->get_link_with_relationship('oauth-access-token-endpoint');

    my $request = Net::OAuth->request("access token")->new(
        consumer_key => $self->{consumer_key},
        consumer_secret => $self->{consumer_secret},
        token => $request_token,
        token_secret => $request_token_secret,
        request_url => $access_token_link->href,
        request_method => 'POST',
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->_nonce(),
    );

    $request->sign();

    my $ua = LWP::UserAgent->new();
    $ua->agent('WebService::TypePad/'.$WebService::TypePad::VERSION);

    my $req = HTTP::Request->new(POST => $access_token_link->href);
    $req->content_type("application/x-www-form-urlencoded");
    $req->content($request->to_post_body());

    my $res = $ua->request($req);

    croak "Failed to obtain access token" unless $res->is_success;

    my $response = Net::OAuth->response('access token')->from_post_body($res->content);

    my $access_token = $response->token;
    my $access_token_secret = $response->token_secret;

    return ($access_token, $access_token_secret);

}

sub _api_client {
    my ($self) = @_;

    return WebService::TypePad->new(
        backend_url => $self->{backend_url},
    );
}

sub _application_object {
    my ($self) = @_;

    my $typepad = $self->_api_client;
    my $app = $typepad->application($self->{consumer_key});
    my $req = $typepad->new_request();
    $req->add_task('app' => $app->load_task());
    my $result = $req->run();

    return $result->{app};
}

sub _nonce {
    return int(rand(2**32));
}

1;
