
=head1 NAME

WebService::TypePad::Util::JSON - JSON utility functions

=head1 DESCRIPTION

This is just a wrapper around a singleton JSON object, ensuring that everywhere
we deal with JSON we do it in a consistent way.

We use JSON::Any in order to work with various underlying JSON libraries
from CPAN.

=cut

package WebService::TypePad::Util::JSON;

use strict;
use warnings;

use JSON::Any;
use Exporter 'import';

our @EXPORT = qw(json_encode json_decode json_true json_false);

=head1 FUNCTIONS

The functions in this package are not class methods. All will be imported into
your package namespace by default.

=cut

my $json = JSON::Any->new();

=pod

=head2 json_encode($ref)

Given some JSON-able reference (usually a HASH ref), return a JSON string.

=cut

sub json_encode {
    my ($value) = @_;
    return $json->encode($value);
}

=pod

=head2 json_decode($ref)

Given a JSON string, parse it and return some kind of reference (usually a HASH ref).

=cut

sub json_decode {
    my ($value) = @_;
    return $json->decode($value);
}

=pod

=head2 json_true

Returns some value that, when passed into C<encode>, will lead to a JSON true value being generated.

=cut

sub json_true {
    return $json->true;
}

=pod

=head2 json_false

Returns some value that, when passed into C<encode>, will lead to a JSON false value being generated.

=cut

sub json_false {
    return $json->false;
}


1;
