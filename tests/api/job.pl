use strict;
use Setup;
use JSON;
use URI;

use Test::Simple tests => 2;

my $jobset = createBaseJobset("api-5", "basic.nix");
evalSucceeds($jobset);
foreach my $build (queuedBuildsForJobset($jobset)) {
    runBuild($build);
}

my $data = decode_json(request_json({ uri => "/job/tests/api-5/empty_dir"})->content());

foreach my $build (@{$data->{lastBuilds}}) {
    ok($build->{finished} == 1, "A build is finished after it has run");
    ok($build->{buildstatus} == 0, "A build that succeeds is reported as successful");
}
