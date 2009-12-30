
use WebService::TypePad::Object;

my @classes_to_try = ();

foreach my $type (keys %WebService::TypePad::Object::Object_Types) {
    my $class = $WebService::TypePad::Object::Object_Types{$type};
    push @classes_to_try, $class;
}

require 'Test/More.pm';
Test::More->import(tests => scalar(@classes_to_try));

foreach my $class (@classes_to_try) {
    use_ok($class);
}
