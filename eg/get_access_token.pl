
use WebService::TypePad::Auth;

use strict;
use warnings;
use Data::Dumper;

my $auth = WebService::TypePad::Auth->new(
    consumer_key => 'YOUR_CONSUMER_KEY',
    consumer_secret => 'YOUR_ACCESS_TOKEN',
);

my ($request_token, $request_token_secret) = $auth->request_token(
    callback_url => 'http://example.com/callback',
);

warn "Request token is $request_token and its secret is $request_token_secret";

my $authorization_url = $auth->authorization_url(
    request_token => $request_token,
    request_token_secret => $request_token_secret,
);

warn "Auth URL is $authorization_url";

print STDERR "Please go over there and approve me. Once you've done so, pull the oauth_verifier parameter value out of the resulting URL and paste it in here and then hit enter.\n> ";

my $verifier = <STDIN>;
chomp($verifier);

my ($access_token, $access_token_secret) = $auth->access_token(
    request_token => $request_token,
    request_token_secret => $request_token_secret,
    verifier => $verifier,
);

warn "Access token is $access_token and its secret is $access_token_secret";

# FIXME: Need to also put the session sync token somewhere!

