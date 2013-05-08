use strict;
use Setup;
use JSON;

use Test::Simple tests => 2;

login();
my $user = decode_json(request_json({ uri => "/current-user" })->content());

for my $role (@{$user->{userroles}}) {
    if ($role->{role} eq 'admin') {
        ok(1, "Root has admin role");
    } elsif ($role->{role} eq 'foo') {
        ok(1, "Root has foo role");
    }
}
