
=head1 NAME

WebService::TypePad::Util::Coerce - Utility functions used for coercing values into and out of TypePad::API::Object subclasses

=cut

package WebService::TypePad::Util::Coerce;

use strict;
use warnings;
use WebService::TypePad::Util::JSON;
use WebService::TypePad::Object;
use Set::Tiny;

# Primitive Types

sub coerce_string_in {
    return defined($_[0]) ? "$_[0]" : undef;
}

sub coerce_integer_in {
    return defined($_[0]) ? int($_[0]) : undef;
}

sub coerce_float_in {
    return defined($_[0]) ? $_[0] + 0 : undef;
}

sub coerce_boolean_in {
    return defined($_[0]) ? ($_[0] ? json_true() : json_false()) : undef;
}

sub coerce_boolean_out {
    return defined($_[0]) ? ($_[0] == json_true() ? 1 : 0) : undef;
}

# Collection types
# These are really just wrappers around aome inner coerce function.

{
    my $coerce_array = sub {
        my ($array, $inner_coerce) = @_;
        return undef unless defined($array);
        return [ map { $inner_coerce->($_) } @$array ];
    };

    no strict 'refs';
    *{'WebService::TypePad::Util::Coerce::coerce_array_in'} = $coerce_array;
    *{'WebService::TypePad::Util::Coerce::coerce_array_out'} = $coerce_array;
}

{
    my $coerce_map = sub {
        my ($map, $inner_coerce) = @_;
        return undef unless defined($map);
        my $ret = {};
        map { my $k = $_; $ret->{$k} = $inner_coerce->($map->{$k}) } keys %$map;
        return $ret;
    };

    no strict 'refs';
    *{'WebService::TypePad::Util::Coerce::coerce_map_in'} = $coerce_map;
    *{'WebService::TypePad::Util::Coerce::coerce_map_out'} = $coerce_map;
}

sub coerce_set_in {
    my ($set, $inner_coerce) = @_;

    return undef unless defined($set);

    my $items = [ sort $set->members ];
    return coerce_array_in($items, $inner_coerce);
}

sub coerce_set_out {
    my ($list, $inner_coerce) = @_;

    return undef unless defined($list);

    my $items = coerce_array_out($list, $inner_coerce);
    return Set::Tiny->new(@$items);
}

# Object types
# The implementation of these is always the same modulo
# the underlying class name.

{

    # The in func is always the same
    my $in_func = sub {
        my ($obj) = @_;
        return undef unless defined($obj);
        return $obj->_as_json_dictionary;
    };

    foreach my $type (keys %WebService::TypePad::Object::Object_Types) {
        my $class = $WebService::TypePad::Object::Object_Types{$type};
        my $in_name = 'coerce_'.$type.'_in';
        my $out_name = 'coerce_'.$type.'_out';

        my $out_func = sub {
            my ($dict) = @_;
            return undef unless defined($dict);
            eval "use $class;";
            die "Failed to load package $class: $@" if $@;
            return $class->_from_json_dictionary($dict);
        };

        {
            no strict 'refs';
            *{__PACKAGE__.'::'.$in_name} = $in_func;
            *{__PACKAGE__.'::'.$out_name} = $out_func;
        }

    }

}

1;


