
use WebService::TypePad::Util::Coerce;
use WebService::TypePad::Object;

my @functions_to_try = ();

# Object types
foreach my $type_uri (keys %WebService::TypePad::Object::Object_Types) {
    my $class = $WebService::TypePad::Object::Object_Types{$type_uri};
    if ($class =~ /::(\w+)$/) {
        my $type = $1;
        push @functions_to_try, 'coerce_'.$type.'_in';
        push @functions_to_try, 'coerce_'.$type.'_out';
    }
}

# Primitive types. These only coerce on the way in.
foreach my $type (qw(string integer boolean float)) {
    push @functions_to_try, 'coerce_'.$type.'_in';
}
# Except boolean, which also coerces on the way out because
# the internal representation is silly JSON  \0 and \1 constants.
push @functions_to_try, 'coerce_boolean_out';

# Collection types. These coerce both ways.
foreach my $type (qw(array map set)) {
    push @functions_to_try, 'coerce_'.$type.'_in';
    push @functions_to_try, 'coerce_'.$type.'_out';
}

my $test_count = scalar(@functions_to_try);

require 'Test/More.pm';
Test::More->import(tests => $test_count);

foreach my $function (@functions_to_try) {
    ok(WebService::TypePad::Util::Coerce->can($function), "$function exists");
}


