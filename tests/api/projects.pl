use strict;
use Setup;
use JSON;

use Test::Simple tests => 4;

createBaseJobset("api-1", "release.nix");
createBaseJobset("api-2", "default.nix");

my $res = request_json({ uri => "/project/tests" });

print $res->as_string();

ok($res->code() == 200, "Can get existing project");

my $data = decode_json($res->content);

ok($data->{project}->{name} eq "tests", "The project's name is tests");

foreach my $jobset (@{$data->{jobsets}}) {
    if ($jobset->{name} eq "api-1" or $jobset->{name} eq "api-2") {
        ok(1, "Found jobset maned $jobset->{name}");
    }
}
