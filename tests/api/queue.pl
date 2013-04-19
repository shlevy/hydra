use strict;
use Setup;
use JSON;
use URI;
use Test::Simple;

my $jobset = createBaseJobset("api-6", "basic.nix");
evalSucceeds($jobset);

my $data = decode_json(request_json({ uri => "/queue"})->content());

foreach my $build (@{$data}) {
    ok(defined $build->{system}, "Builds have systems");
}
