use strict;
use Setup;
use JSON;

use Test::Simple tests => 1;

login();
my $user = decode_json(request_json({ uri => "/current-user" })->content());

for my $role (@{$user->{roles}}) {
    if ($role->{role} eq 'admin') {
        ok(1, "Root has admin role");
    }
}
