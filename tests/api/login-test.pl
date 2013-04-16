use strict;
use Hydra::Schema;
use Hydra::Model::DB;
use Hydra::Helper::AddBuilds;
use Cwd;
use Setup;

use Test::Simple tests => 2;

my $code = request_json({ uri => "/session", method => "POST", data => { username => "root", password => "foobaz" } })->code();
ok($code == 403, "A login request with a bad password should be unauthorized, code was $code");
$code = request_json({ uri => "/session", method => "POST", data => { username => "root", password => "foobaz" } })->code();
ok($code == 204, "A login request with the right password should succeed, code was $code");
