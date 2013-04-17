use strict;
use Hydra::Schema;
use Hydra::Model::DB;
use Hydra::Helper::AddBuilds;
use Cwd;
use Setup;

use Test::Simple tests => 3;

login();
my $code = request_json({ uri => "/admin/users", method => "GET" })->code();
ok($code == 200, "A logged-in admin should be able to get the list of users, code was $code");
$code = request_json({ uri => "/logout", method => "POST" })->code();
ok($code == 204, "A logout request should succeed, code was $code");
$code = request_json({ uri => "/admin/users", method => "GET" })->code();
ok($code == 403, "A logged-out user should be forbidden from getting the list of users, code was $code");
