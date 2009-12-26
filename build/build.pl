
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
    }
    print OUT ");\n";

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

    print OUT "our %Object_Types = (\n";
    foreach my $object_type (@$object_types) {
	my $type_name = $object_type->{name};
	my $accessor_name = accessor_for_object_type($type_name);
	my $class_name = class_for_object_type($type_name);
	print OUT "    '$accessor_name' => 'WebService::TypePad::Object::$class_name',\n";
    }
    print OUT ");\n";

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


