
=head1 NAME

WebService::TypePad::Request - TypePad API Batch Request

=head1 SYNOPSIS

    use WebService::TypePad;
    my $typepad = WebService::TypePad->new();
    my $request = $typepad->new_request();
    $request->add_task('user', $typepad->user('melody')->load_task());
    $request->add_task('memberships', $typepad->user('melody')->load_memberships_task());
    my $result = $request->run();
    my $user = $result->{user};
    my $memberships = $result->{memberships};

=head1 DESCRIPTION

This class provides the mechanism to make batch requests to the TypePad API.

It is not to be instantiated directly; instead, use the C<new_request> method on
L<WebService::TypePad>.

=cut

package WebService::TypePad::Request;

use strict;
use warnings;
use Carp;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Multi;
use WebService::TypePad::Util::JSON;
use Net::OAuth;

BEGIN {
    eval {  require Math::Random::MT };
    unless ($@) {
        Math::Random::MT->import(qw(srand rand));
    }
}

sub new_for_api {
    my ($class, $api) = @_;

    my $self = bless {}, $class;
    $self->{api} = $api;
    $self->{tasks} = {};
    return $self;
}

sub add_task {
    my ($self, $task_name, $task) = @_;

    croak "This request object already contains a task named $task_name" if defined($self->{tasks}{$task_name});
    $self->{tasks}{$task_name} = $task;
    1;
}

sub run {
    my ($self) = @_;

    my $ua = LWP::UserAgent->new();
    $ua->agent('WebService::TypePad/'.$WebService::TypePad::VERSION);

    my $requests = {};
    my $results = {};

    my $num_tasks = scalar(keys(%{$self->{tasks}}));

    return {} if $num_tasks == 0;

    if ($num_tasks == 1) {

        my ($key) = keys(%{$self->{tasks}});
        my $task = $self->{tasks}{$key};

        my $req = $self->_task_to_http_request($task);
        $self->_add_auth_to_request($req);
        my $res = $ua->request($req);

        return { $key => $self->_http_response_to_result($res, $task) };

    }
    else {

        foreach my $task_name (keys %{$self->{tasks}}) {
            my $task = $self->{tasks}{$task_name};
            $requests->{$task_name} = $self->_task_to_http_request($task);
        }

        my $req = HTTP::Request::Multi->create_request($self->{api}->url()."batch-processor", $requests);
        $self->_add_auth_to_request($req);
        my $res = $ua->request($req);

        if ($res->is_success) {

            my %responses = HTTP::Request::Multi->parse_response($res);

            print STDERR Data::Dumper::Dumper(\%responses);

            foreach my $task_name (keys %{$self->{tasks}}) {
                my $task = $self->{tasks}{$task_name};

                my $res = $responses{$task_name} || croak "Server did not return a response for task $task_name";

                $results->{$task_name} = $self->_http_response_to_result($res, $task);
            }

        }
        else {
            croak "Batch request failed: ".$res->status_line;
        }

        return $results;

    }

}

sub _task_to_http_request {
    my ($self, $task) = @_;

    # For now, we assume all requests are unauthed. Later will need to add
    # an additional field to Task to determine whether the request should
    # be authed and perhaps whether it should auth as the group or the user.

    my $url = $self->{api}->backend_url() . join('/', @{$task->path_chunks}) . '.json';
    my $method = $task->method;

    my $req = HTTP::Request->new($method => $url);

    if (my $headers = $task->headers) {
        $headers->scan(sub {
            my ($name, $value) = @_;
            $req->headers->push_header($name => $value);
        });
    }

    if (my $body = $task->body) {
        if (ref $body) {
            my $json_body = json_encode($body);
            $req->header('Content-Type' => 'application/json');
            $req->header('Content-Length' => length($json_body));
            $req->content($json_body);
        }
        else {
            $req->header('Content-Length' => length($body));
            $req->content($body);
        }
    }

    return $req;

}

sub _http_response_to_result {
    my ($self, $res, $task) = @_;

    if ($res->is_success) {
        my $body;

        if ($res->content_type eq 'application/json') {
            $body = json_decode($res->content);
        }
        else {
            $body = $res->content;
        }

        if (my $handler = $task->result_handler) {
            $body = $handler->($body);
        }

        return $body;
    }
    else {
        # Return the HTTP::Response object so the caller can extract the
        # status, etc.
        return $res;
    }

}

sub _add_auth_to_request {
    my ($self, $req) = @_;

    return unless $self->{api}->authenticated;

    my $url = $req->uri;
    my $method = $req->method;

    my $bare_url = $url->clone;
    $bare_url->query('');
    my $extra_args = $url->query_form;

    my $request = Net::OAuth->request('protected resource')->new(
        $self->{api}->oauth_parameters,
        request_url => $url->canonical."",
        request_method => $method,
        extra_params => $extra_args,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->_nonce(),
    );

    $request->sign();

    print STDERR "OAuth request is ".Data::Dumper::Dumper($request);

    my $auth_header = $request->to_authorization_header();

    $req->header('Authorization' => $auth_header);
    print STDERR "The auth header is ".$req->as_string."\n";
}

sub _nonce {
    return int(rand(2**32));
}

1;
