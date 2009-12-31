
=head1 NAME

build/build.pl - Constructs the local stubs for the remote operations and object types documented in nouns.yaml and object-types.yaml

=cut

use strict;
use warnings;

use Carp qw(croak);
use FindBin;
use lib "$FindBin::Bin/../lib";
chdir "$FindBin::Bin/..";

use WebService::TypePad::Util::JSON;

my $nouns_dict = load_json_file("nouns.json");
my $object_types_dict = load_json_file("object-types.json");

my $nouns = $nouns_dict->{entries};
my $object_types = $object_types_dict->{entries};

my %noun_for_object_type = ();

# Create WebService::TypePad::Noun package
{

    mkdir("lib/WebService/TypePad/Noun");
    local *OUT;
    open(OUT, '>', "lib/WebService/TypePad/Noun.pm");

    print OUT "package WebService::TypePad::Noun;\n";
    print OUT "use strict;\n";
    print OUT "use warnings;\n";

    print OUT "our %Nouns = (\n";
    foreach my $noun (@$nouns) {
        my $noun_name = $noun->{name};
        my $accessor_name = accessor_for_noun($noun_name);
        my $class_name = class_for_noun($noun_name);
        print OUT "    '$accessor_name' => 'WebService::TypePad::Noun::$class_name',\n";

        if (my $object_type = $noun->{resourceObjectType}) {
            $noun_for_object_type{$object_type->{name}} = $noun_name;
        }
    }
    print OUT ");\n";

    print OUT "1;\n";

    print OUT "\n=head1 NAME\n";
    print OUT "\nWebService::TypePad::Noun - Container for noun classes\n";
    print OUT "\n=head1 SYNOPSIS\n";
    print OUT "\n    use WebService::TypePad;\n";
    print OUT "    my \$typepad = WebService::TypePad->new();\n";
    print OUT "    # Call a method on the \"users\" noun\n";
    print OUT "    my \$user = \$typepad->users->load_user(\$user_id);\n";
    print OUT "\n=head1 AVAILABLE NOUNS\n";
    print OUT "\n=over 1\n";
    foreach my $noun (@$nouns) {
        my $noun_name = $noun->{name};
        my $accessor_name = accessor_for_noun($noun_name);
        my $class_name = class_for_noun($noun_name);
        print OUT "\n=item * L<$accessor_name|WebService::TypePad::Noun::$class_name>\n";
    }
    print OUT "\n=back\n";

    close(OUT);

}

# Create WebService::TypePad::Object package
{
    mkdir("lib/WebService/TypePad/Object");
    local *OUT;
    open(OUT, '>', "lib/WebService/TypePad/Object.pm");

    print OUT "package WebService::TypePad::Object;\n";
    print OUT "use strict;\n";
    print OUT "use warnings;\n";
    print OUT "use fields qw(last_known_etag data);\n";

    print OUT "our %Object_Types = (\n";
    foreach my $object_type (@$object_types) {
        my $type_name = $object_type->{name};
        my $accessor_name = accessor_for_object_type($type_name);
        my $class_name = class_for_object_type($type_name);
        print OUT "    '$type_name' => 'WebService::TypePad::Object::$class_name',\n";
    }
    print OUT ");\n";
    print OUT "our %Object_Type_Classes_By_Uri = (\n";
    foreach my $object_type (@$object_types) {
        my $type_name = $object_type->{name};
        my $accessor_name = accessor_for_object_type($type_name);
        my $class_name = class_for_object_type($type_name);
        print OUT "    'tag:api.typepad.com,2009:$type_name' => 'WebService::TypePad::Object::$class_name',\n";
    }
    print OUT ");\n";

    print OUT "sub new {\n";
    print OUT "    my (\$class, \%params) = \@_;\n";
    print OUT "    my \$self = fields::new(\$class);\n";
    print OUT "    \$self->{data} = {};\n";
    print OUT "    map { \$self->\$_(\$params{\$_}) } keys \%params;\n";
    print OUT "    return \$self;";
    print OUT "}\n";
    print OUT "sub _from_json_dictionary {\n";
    print OUT "    my (\$class, \$dict) = \@_;\n";
    print OUT "    if (my \$object_types = \$dict->{objectTypes}) {\n";
    print OUT "        foreach my \$type_uri (\@\$object_types) {\n";
    print OUT "            if (my \$class_name = \$Object_Type_Classes_By_Uri{\$type_uri}) {\n";
    print OUT "                \$class = \$class_name;\n";
    print OUT "            }\n";
    print OUT "        }\n";
    print OUT "    }\n";
    print OUT "    my \$self = \$class->new();\n";
    print OUT "    \$self->{data} = \$dict;\n";
    print OUT "    return \$self;";
    print OUT "}\n";
    print OUT "sub _as_json_dictionary {\n";
    print OUT "    return \$_[0]->{data};\n";
    print OUT "}\n";

    print OUT "1;\n";

    print OUT "\n=head1 NAME\n";
    print OUT "\nWebService::TypePad::Object - Base class for our local representations of TypePad's object types\n";
    print OUT "\n=head1 SYNOPSIS\n";
    print OUT "\n    # Create a new \"user\" object\n";
    print OUT "    use TypePad::API::Object::User;\n";
    print OUT "    my \$user = TypePad::API::Object::User->new();\n";
    print OUT "\n=head1 AVAILABLE OBJECT TYPES\n";
    print OUT "\n=over 1\n";
    foreach my $object_type (@$object_types) {
        my $type_name = $object_type->{name};
        my $accessor_name = accessor_for_object_type($type_name);
        my $class_name = class_for_object_type($type_name);
        print OUT "\n=item * L<WebService::TypePad::Object::$class_name>\n";
    }
    print OUT "\n=back\n";

    close(OUT);
}

# Create a package for each object type
{

    foreach my $object_type (@$object_types) {
        my $type_name = $object_type->{name};
        my $class_name = class_for_object_type($type_name);
        my $accessor_name = accessor_for_object_type($type_name);

        my $fn = "lib/WebService/TypePad/Object/$class_name.pm";
        local *OUT;
        open(OUT, '>', $fn);

        print OUT "package WebService::TypePad::Object::$class_name;\n";
        print OUT "use strict;\n";
        print OUT "use warnings;\n";
        print OUT "use WebService::TypePad::Util::Coerce;\n";

        if (my $base_type_name = $object_type->{parentType}) {
            my $parent_class_name = class_for_object_type($base_type_name);
            print OUT "use base qw(WebService::TypePad::Object::$parent_class_name);\n";
        }
        else {
            print OUT "use base qw(WebService::TypePad::Object);\n";
        }

        print OUT "\n";

        foreach my $property (@{$object_type->{properties}}) {
            my $property_name = $property->{name};
            my $accessor_name = accessor_for_property($property_name);
            my $type = $property->{type};

            # Entirely lowercase means primitive type
            my $is_primitive = ($type =~ /^[a-z]+$/);

            print OUT "sub $accessor_name {\n";
            print OUT "    my \$self = shift;\n";
            print OUT "    if (\@_) {\n";


            # Generate setter code
            {
                my $coerce_function_name = undef;
                my $coerce_function_modifier = undef;

                if ($type =~ /^(\w+)<(\w+)>$/) {
                    my $generic_type = $1;
                    my $inner_type = $2;
                    $coerce_function_modifier = 'coerce_'.$inner_type.'_in';

                    if ($generic_type eq 'List') {
                        $coerce_function_name = 'coerce_list_in';
                    }
                    elsif ($generic_type eq 'array') {
                        $coerce_function_name = 'coerce_array_in';
                    }
                    elsif ($generic_type eq 'set') {
                        # We only actually have special handling for sets of string.
                        # For other kinds of sets we just return a list and let the caller deal with it.
                        if ($inner_type eq 'string') {
                            $coerce_function_name = 'coerce_set_in';
                        }
                        else {
                            $coerce_function_name = 'coerce_list_in';
                        }
                    }
                    elsif ($generic_type eq 'map') {
                        $coerce_function_name = 'coerce_map_in';
                    }
                    else {
                        die "I don't know how to coerce values of this new generic type $generic_type in type $type";
                    }
                }
                elsif ($type =~ /^(\w+)$/) {
                    $coerce_function_name = 'coerce_'.$type.'_in';
                }
                else {
                    die "I don't know how to coerce values of this new type $type";
                }

                print OUT "        \$self->{data}{$property_name} = WebService::TypePad::Util::Coerce::$coerce_function_name(\$_[0]". ($coerce_function_modifier ? ", \\\&WebService::TypePad::Util::Coerce::$coerce_function_modifier" : "") . ");\n";
                print OUT "        return \$_[0];\n";
            }

            print OUT "    }\n";
            print OUT "    else {\n";

            # Generate getter code
            {

                my $coerce_function_name = undef;
                my $coerce_function_modifier = undef;

                if ($is_primitive) {
                    if ($type eq 'boolean') {
                        $coerce_function_name = 'coerce_boolean_out';
                    }
                }
                else {
                    if ($type =~ /^(\w+)<(\w+)>$/) {
                        my $generic_type = $1;
                        my $inner_type = $2;
                        my $inner_is_primitive = ($inner_type =~ /^[a-z]+$/);
                        $coerce_function_modifier = 'coerce_'.$inner_type.'_out' unless $inner_is_primitive || $inner_type eq 'boolean';

                        if ($generic_type eq 'List') {
                            $coerce_function_name = 'coerce_list_out';
                        }
                        elsif ($generic_type eq 'array') {
                            $coerce_function_name = 'coerce_array_out';
                        }
                        elsif ($generic_type eq 'set') {
                            # We only actually have special handling for sets of string.
                            # For other kinds of sets we just return a list and let the caller deal with it.
                            if ($inner_type eq 'string') {
                                $coerce_function_name = 'coerce_set_out';
                            }
                            else {
                                $coerce_function_name = 'coerce_array_out';
                            }
                        }
                        elsif ($generic_type eq 'map') {
                            $coerce_function_name = 'coerce_map_out';
                        }
                        else {
                            die "I don't know how to coerce values of this new generic type $generic_type in type $type";
                        }
                    }
                    elsif ($type =~ /^\w+$/) {
                        $coerce_function_name = 'coerce_'.$type.'_out';
                    }
                    else {
                        die "I don't know how to coerce values of this new type $type";
                    }
                }

                if ($coerce_function_name) {
                    print OUT "        return WebService::TypePad::Util::Coerce::$coerce_function_name(\$self->{data}{$property_name}". ($coerce_function_modifier ? ", \\\&WebService::TypePad::Util::Coerce::$coerce_function_modifier" : "") . ");\n";
                }
                else {
                    print OUT "        return \$self->{data}{$property_name};\n";
                }
            }

            print OUT "    }\n";
            print OUT "}\n\n";
        }

        print OUT "1;\n";

        # Now generate some POD

        print OUT "\n=head1 NAME\n";
        print OUT "\nWebService::TypePad::Object::$class_name - Perl representation of TypePad's $class_name object type\n";
        print OUT "\n=head1 SYNOPSIS\n";
        print OUT "\n    use WebService::TypePad::Object::$class_name;\n";
        print OUT "    my \$$accessor_name = WebService::TypePad::Object::$class_name->new();\n";
        print OUT "\n=head1 DESCRIPTION\n";
        print OUT "\nThis is a Perl representation of TypePad's $class_name object type.\n";
        print OUT "For more information about this type and its parameters, see L<the documentation on TypePad's developer site|http://www.typepad.com/services/apidocs/objecttypes/$class_name>.\n";
        if (my $base_type_name = $object_type->{parentType}) {
            print OUT "\nThis is a subtype of L<$base_type_name|WebService::TypePad::Object::$base_type_name>.\n" if $base_type_name ne 'Base';
        }
        print OUT "\n=head1 PROPERTIES\n";
        print OUT "\nEach of these properties has an accessor method which will retrieve the property's value when called with no arguments or set the property's value when called with one argument.\n";

        my $type_accessor_name = $accessor_name;
        foreach my $property (sort {$a->{name} cmp $b->{name}} @{$object_type->{properties}}) {
            my $property_name = $property->{name};
            my $accessor_name = accessor_for_property($property_name);
            my $type = $property->{type};
            my $doc_string = typepad_pod_to_real_pod($property->{docString});

            my $type_as_pod;

            if ($type =~ /^[a-z]+$/) {
                $type_as_pod = "a single C<$type> value";
            }
            elsif ($type =~ /^(\w+)<(\w+)>$/) {
                my $generic_type = $1;
                my $inner_type = $2;
                $generic_type = 'array' if $generic_type eq 'set' && $inner_type ne 'string';
                my $article = $generic_type eq 'array' ? 'an' : 'a';
                if ($inner_type =~ /^[a-z]+$/) {
                    $type_as_pod = "$article $generic_type of C<$inner_type> values";
                }
                else {
                    $type_as_pod = "$article $generic_type of L<$inner_type|WebService::TypePad::Object::$inner_type> objects";
                }
            }
            else {
                $type_as_pod = "a single L<$type|WebService::TypePad::Object::$type> object";
            }

            print OUT "\n=head2 \$$type_accessor_name->$accessor_name\n";
            print OUT "\n$doc_string\n";
            print OUT "\nReturns $type_as_pod.\n";

        }

        print OUT "\n=head1 SEE ALSO\n";
        print OUT "\n=over 1\n";
        if (my $noun_name = $noun_for_object_type{$type_name}) {
            my $noun_class = class_for_noun($noun_name);
            print OUT "\n=item * L<WebService::TypePad::Noun::$noun_class>\n";
        }
        print OUT "\n=item * L<http://www.typepad.com/services/apidocs/objecttypes/$type_name>\n";
        print OUT "\n=back\n";


        close(OUT);

    }

}

# Create a package for each noun
{

    foreach my $noun (@$nouns) {
        my $noun_name = $noun->{name};
        my $class_name = class_for_noun($noun_name);

        my $fn = "lib/WebService/TypePad/Noun/$class_name.pm";
        local *OUT;
        open(OUT, '>', $fn);

        print OUT "package WebService::TypePad::Noun::$class_name;\n";
        print OUT "use strict;\n";
        print OUT "use warnings;\n";
        print OUT "use Carp qw(croak);\n";
        print OUT "use WebService::TypePad::Util::Coerce;\n";
        print OUT "use WebService::TypePad::Task;\n";

        print OUT "\n";

        print OUT "sub _new_for_client {\n";
        print OUT "    my (\$class, \$typepad) = \@_;\n";
        print OUT "    my \$self = bless [ \$typepad ], \$class;\n";
        print OUT "    return \$self;\n";
        print OUT "}\n";
        print OUT "sub client {\n";
        print OUT "    return \$_[0][0];\n";
        print OUT "}\n";

        print OUT "\n";

        my %prefix_for_http_method = (
            'GET' => 'get_',
            'PUT' => 'put_',
            'POST' => 'post_to_',
            'DELETE' => 'delete_',
            # TODO: Add OPTIONS here?
        );

        my %endpoints_by_method_name = ();

        my $make_single_request_shorthand = sub {
            my ($method_name) = @_;

            print OUT "sub $method_name {\n";
            print OUT "    my (\$self, \%params) = \@_;\n";

            print OUT "    my \$task = \$self->${method_name}_task(\%params);\n";
            print OUT "    my \$request = \$self->client->new_request();\n";
            print OUT "    \$request->add_task('', \$task);\n";
            print OUT "    my \$result = \$request->run();\n";
            print OUT "    my \$response = \$result->{''};\n";
            print OUT "    if (UNIVERSAL::isa(\$response, 'HTTP::Response')) {\n";
            print OUT "        die \$response;\n";
            print OUT "    }\n";
            print OUT "    else {\n";
            print OUT "        return \$response;\n";
            print OUT "    }\n";

            print OUT "}\n\n";
        };

        my $make_resource_endpoint_methods;
        $make_resource_endpoint_methods = sub {
            my @parts = @_;
            my $endpoint = $parts[$#parts];
            my ($noun, $sub_resource, @filters) = @parts;

            my $noun_name = $noun->{name};

            my $noun_resource_object_type = $noun->{resourceObjectType};
            # Can't auto-generate methods for nouns that don't follow the
            # Data API conventions, such as BatchProcessor and BrowserUpload.
            return unless $noun_resource_object_type;

            my $noun_resource_object_type_name = $noun_resource_object_type->{name};

            # Right now only interested in generating methods for nouns that
            # can have id, since they all can except the weird ones.
            return unless $noun->{canHaveId};

            my $endpoint_resource_object_type = $endpoint->{resourceObjectType};
            return unless $endpoint_resource_object_type;
            my $endpoint_resource_object_type_name = $endpoint_resource_object_type->{name};

            my $noun_resource_param_name = accessor_for_object_type($noun_resource_object_type_name);

            my $method_base_name;

            my @params = ($noun_resource_param_name);
            my @path_chunks = ("'".$noun_name."'", '$'.$noun_resource_param_name.'_param');

            if (@filters) {
                # Filter-y name

                my $property_name = $sub_resource->{name};
                push @path_chunks, "'".$property_name."'";
                $property_name =~ y/-/_/;

                my @simple_filters = ();
                my @param_filters = ();

                foreach my $filter (@filters) {
                    my $filter_name = $filter->{name};
                    my $filter_method_name = $filter_name;
                    $filter_method_name =~ y/-/_/;

                    if ($filter->{parameterized}) {
                        # Trim off the by- prefix
                        push @param_filters, substr($filter_method_name, 3);
                        push @params, $filter_method_name;
                        push @path_chunks, "'\@".$filter_name."'", '$'.$filter_method_name.'_param';
                    }
                    else {
                        push @path_chunks, "'\@".$filter_name."'";
                        push @simple_filters, $filter_method_name;
                    }
                }

                $method_base_name = join('_',
                    $noun_resource_param_name,
                    @simple_filters,
                    $property_name,
                    (
                        @param_filters ? (
                            'by',
                            join('_and_', @param_filters)
                        ) : ()
                    )
                );
            }
            elsif ($sub_resource) {
                # /users/<id>/memberships becomes user_memberships
                my $property_name = $sub_resource->{name};
                push @path_chunks, "'".$property_name."'";
                $property_name =~ y/-/_/;
                $method_base_name = join('_', $noun_resource_param_name, $property_name);
            }
            else {
                $method_base_name = $noun_resource_param_name;
            }

            $endpoints_by_method_name{$method_base_name} = $endpoint;

            foreach my $http_method (keys %{$endpoint->{supportedMethods}}) {
                my $prefix = $prefix_for_http_method{$http_method};
                next unless $prefix;

                my $method_name = join('', $prefix, $method_base_name);
                my $id_param_name = $noun_resource_param_name."_id";

                if ($http_method eq 'GET') {
                    print OUT "sub ${method_name}_task {\n";
                    print OUT "    my (\$self, \%params) = \@_;\n";
                    foreach my $param_name (@params) {
                        print OUT "    my \$${param_name}_param = delete \$params{$param_name};\n";
                    }
                    print OUT "    my \$obj = delete \$params{$noun_resource_param_name};\n";
                    print OUT "    croak \"Invalid params: \".join(',', keys(\%params)) if %params;\n";
                    print OUT "    return WebService::TypePad::Task->new(\n";
                    print OUT "        path_chunks => [ ".join(', ', @path_chunks)." ],\n";
                    print OUT "        result_handler => sub {\n";
                    print OUT "            my (\$dict) = \@_;\n";
                    print OUT "            return ".coerce_call('$dict', $endpoint_resource_object_type_name, 'out').";\n";
                    print OUT "        },\n";
                    print OUT "    );\n";
                    print OUT "}\n\n";
                    $make_single_request_shorthand->($method_name);
                }
            }

            # Methods for child endpoints?
            if (@filters) {
                # This is a filter. Does it have more filters under it?
                foreach my $filter (@{$endpoint->{filterEndpoints}}) {
                    $make_resource_endpoint_methods->(@parts, $filter);
                }
            }
            elsif ($sub_resource) {
                # It's a property. Does it have any filters?
                foreach my $filter (@{$endpoint->{filterEndpoints}}) {
                    $make_resource_endpoint_methods->(@parts, $filter);
                }
            }
            else {
                # It's a noun. Does it have any properties?
                foreach my $property (@{$endpoint->{propertyEndpoints}}) {
                    $make_resource_endpoint_methods->($noun, $property);
                }
                # FIXME: Also do action endpoints.
            }
        };

        my $make_action_endpoint_methods = sub {
            my ($noun, $action) = @_;
        };

        $make_resource_endpoint_methods->($noun);

        print OUT "1;\n";

        close(OUT);
    }
}

sub load_json_file {
    my ($fn) = @_;

    local *IN;
    open(IN, '<', "build/$fn") or croak "Can't open file build/$fn for reading: $!";
    my $data = join('', <IN>);
    close(IN);
    return json_decode($data);
}

sub accessor_for_noun {
    my ($noun_name) = @_;
    $noun_name =~ y/-/_/;
    return $noun_name;
}

sub class_for_noun {
    my ($noun_name) = @_;
    $noun_name =~ s/-(\w)/uc($1)/ge;
    return ucfirst($noun_name);
}

sub accessor_for_object_type {
    my ($type_name) = @_;
    $type_name =~ s/(\w)([A-Z])/$1."_".$2/ge;
    return lc($type_name);
}

sub class_for_object_type {
    # No change necessary
    return $_[0];
}

sub accessor_for_property {
    my ($type_name) = @_;
    $type_name =~ s/(\w)([A-Z])/$1."_".$2/ge;
    return lc($type_name);
}

sub typepad_pod_to_real_pod {
    my ($str) = @_;

    $str =~ s/T<(.*?)>/B<$1.>/g;
    $str =~ s/L<(.*?)\|(.*?)>/$2/g;
    $str =~ s/O<(\w+)>/L<$1|WebService::TypePad::Object::$1>/g;

    return $str;
}

sub coerce_call {
    my ($expr, $type, $direction) = @_;

    if ($type =~ /^(\w+)<(\w+)>$/) {
        my $collection_type = lc($1);
        my $inner_type = $2;

        return "WebService::TypePad::Util::Coerce::coerce_".$collection_type."_".$direction."(".$expr.", \\&WebService::TypePad::Util::Coerce::coerce_".$inner_type."_".$direction.")";
    }
    else {
        return "WebService::TypePad::Util::Coerce::coerce_".$type."_".$direction."(".$expr.")";
    }

}

=head1 USAGE

    build/build.pl

=head1 DESCRIPTION

In order to expedite the creation of new releases of this library when the TypePad API
is changed, much of the client library code is generated mechanically based on the
reflection information provided by the API.

The nouns.yaml and object-types.yaml files in this directory are copies of the information
provided by the server for the release of TypePad that this client library release
is targeting.

From this, L<WebService::TypePad::Noun> and L<WebService::TypePad::Object> and all
of their child packages are created, mixing in some additional code maintained
here in this build directory.


