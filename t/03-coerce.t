
use Test::More tests => 14;
use WebService::TypePad::Util::Coerce;
use WebService::TypePad::Util::JSON;
use WebService::TypePad::Object::User;
use Set::Tiny;
use strict;
use warnings;

diag('Primitives');
is(WebService::TypePad::Util::Coerce::coerce_integer_in('5.2'), 5, 'Coerce 5.2 into integer gives 5');
is(WebService::TypePad::Util::Coerce::coerce_string_in(1e2), "100", 'Coerce 1e2 into string gives 100');
is(WebService::TypePad::Util::Coerce::coerce_float_in(1e2), 100, 'Coerce 1e2 into float gives 100');
is(WebService::TypePad::Util::Coerce::coerce_boolean_in(1), json_true(), 'Coerce 1 into boolean gives json_true');
is(WebService::TypePad::Util::Coerce::coerce_boolean_in(0), json_false(), 'Coerce 0 into boolean gives json_false');
is(WebService::TypePad::Util::Coerce::coerce_boolean_out(json_true()), 1, 'Coerce json_true out of boolean gives 1');
is(WebService::TypePad::Util::Coerce::coerce_boolean_out(json_false()), 0, 'Coerce json_false out of boolean gives 0');

diag('Collections');
my $fake_coerce = sub {
    return $_[0] + 1;
};
is_deeply(WebService::TypePad::Util::Coerce::coerce_array_in([1,2,3], $fake_coerce), [2,3,4], 'Array coerce in works');
is_deeply(WebService::TypePad::Util::Coerce::coerce_map_in({a=>1,b=>2,c=>3}, $fake_coerce), {a=>2,b=>3,c=>4}, 'Map coerce in works');

my $set = Set::Tiny->new(1, 2, 3);
is_deeply(WebService::TypePad::Util::Coerce::coerce_set_in($set, $fake_coerce), [2,3,4], 'Set coerce in works');

my $set2 = WebService::TypePad::Util::Coerce::coerce_set_out([1,2,3], $fake_coerce);
ok(UNIVERSAL::isa($set2, 'Set::Tiny'), 'Set coerce out returns Set::Tiny');
#is_deeply([ sort $set2->members ], [2, 3, 4], 'Set coerce out result contains the expected items');

diag('Objects');
my $user = WebService::TypePad::Util::Coerce::coerce_Entity_out({});
ok(UNIVERSAL::isa($user, 'WebService::TypePad::Object::Entity'), 'Coerce {} out as Entity returned Entity object');

my $user2 = WebService::TypePad::Util::Coerce::coerce_Entity_out({objectTypes => ['tag:api.typepad.com,2009:User']});
ok(UNIVERSAL::isa($user2, 'WebService::TypePad::Object::User'), 'Coerce dict with objectTypes user out via Entity returned User object');

my $user3 = WebService::TypePad::Object::User->new(display_name => "Fred");
my $user3_dict = WebService::TypePad::Util::Coerce::coerce_User_in($user3);
is_deeply($user3_dict, {displayName => "Fred"}, 'Coerce user object in returns expected dict');

