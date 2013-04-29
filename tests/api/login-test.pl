use strict;
use Setup;

use Test::Simple tests => 2;

login();
my $code = request_json({ uri => "/login", method => "POST", data => { username => "root", password => "foobaz" } })->code();
ok($code == 403, "A login request with a bad password should be unauthorized, code was $code");
$code = request_json({ uri => "/login", method => "POST", data => { username => "root", password => "foobar" } })->code();
ok($code == 200, "A login request with the right password should succeed, code was $code");
