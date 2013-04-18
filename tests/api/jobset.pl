use strict;
use Setup;
use JSON;
use URI;

use Test::Simple tests => 1;

my $jobset = createBaseJobset("api-4", "basic.nix");
evalSucceeds($jobset);

my $data = decode_json(request_json({ uri => "/jobset/tests/api-4"})->content());

foreach my $eval (@{$data->{evals}}) {
    ok($eval->{eval}->{nrbuilds} == 3, "A jobset with 3 jobs reports having 3 jobs");
}
