
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

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

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

    my $callback_url = delete $opts{callback_url} or croak "callback_url is required";
    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    # First we ask the server what endpoints we should be using.
    my $application = $self->_application_object;

    my $request_token_url = $application->oauth_request_token_url;

    my $request = Net::OAuth->request("request token")->new(
        consumer_key => $self->{consumer_key},
        consumer_secret => $self->{consumer_secret},
        request_url => $request_token_url,
        request_method => 'POST',
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->_nonce(),
        callback => $callback_url,
    );

    $request->sign();

    my $ua = LWP::UserAgent->new();
    $ua->agent('WebService::TypePad/'.$WebService::TypePad::VERSION);

    my $req = HTTP::Request->new(POST => $request_token_url);
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
    my $target_object = delete $opts{target_object};
    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    if (UNIVERSAL::isa($target_object, "WebService::TypePad::Object")) {
        # Substitute the object's id
        $target_object = $target_object->id;
    }

    my $application = $self->_application_object;
    my $authorization_url = $application->oauth_authorization_url;

    my $auth_request = Net::OAuth->request('user authentication')->new(
        token => $request_token,
        ($target_object ? ( extra_params => { target_object => $target_object } ) : ()),
    );
    return $auth_request->to_url($authorization_url);

}

sub access_token {
    my ($self, %opts) = @_;

    my $request_token = delete $opts{request_token} or die "request_token is required";
    my $request_token_secret = delete $opts{request_token_secret} or die "request_token_secret is required";
    my $verifier = delete $opts{verifier} or die "verifier is required";
    croak "Unsupported argument(s): ".join(', ', keys %opts) if %opts;

    my $application = $self->_application_object;
    my $access_token_url = $application->oauth_access_token_url;

    my $request = Net::OAuth->request("access token")->new(
        consumer_key => $self->{consumer_key},
        consumer_secret => $self->{consumer_secret},
        token => $request_token,
        token_secret => $request_token_secret,
        request_url => $access_token_url,
        request_method => 'POST',
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        verifier => $verifier,
        nonce => $self->_nonce(),
    );

    $request->sign();

    my $ua = LWP::UserAgent->new();
    $ua->agent('WebService::TypePad/'.$WebService::TypePad::VERSION);

    my $req = HTTP::Request->new(POST => $access_token_url);
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
    my $api_key_obj = $typepad->api_keys->get_api_key(api_key => $self->{consumer_key});

    return $api_key_obj->owner;
}

sub _nonce {
    return int(rand(2**32));
}

1;
