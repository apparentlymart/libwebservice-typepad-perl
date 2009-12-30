
=head1 NAME

WebService::TypePad::Task - Represents a single task as a member of a batch request.

=head1 DESCRIPTION

Instances of this class are used with L<WebService::TypePad::Request> to describe
an atomic sub-request in a batch request.

Users of this library shouldn't create objects of this class directly. Instead, use the
task factory methods provided by the various remote object classes.

=cut

package WebService::TypePad::Task;

use strict;
use warnings;
use Carp;

sub new {
    my ($class, %opts) = @_;

    my $path_chunks = delete $opts{path_chunks};
    my $headers = delete $opts{headers};
    my $method = delete $opts{method} || 'GET';
    my $body = delete $opts{body};
    my $result_handler = delete $opts{result_handler};
    my $query_arguments = delete $opts{query_arguments};

    croak "Unknown option(s): ".join(', ', keys %opts) if %opts;

    croak "path_chunks is required" unless $path_chunks;

    my $self = bless {}, $class;
    $self->{path_chunks} = $path_chunks;
    $self->{headers} = $headers;
    $self->{method} = $method;
    $self->{body} = $body;
    $self->{result_handler} = $result_handler;
    return $self;
}

sub path_chunks {
    return $_[0]->{path_chunks};
}

sub headers {
    return $_[0]->{headers};
}

sub method {
    return $_[0]->{method};
}

sub body {
    return $_[0]->{body};
}

sub result_handler {
    return $_[0]->{result_handler};
}

sub query_arguments {
    return $_[0]->{result_handler};
}

1;
