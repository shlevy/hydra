use strict;
use Setup;
use JSON;
use URI;
use Test::Simple;

my $jobset = createBaseJobset("api-7", "long-build.nix");
evalSucceeds($jobset);

my $pid = fork();

die "Couldn't fork" unless defined $pid;

if ($pid == 0) {
    exec "../src/script/hydra-build", $jobset->jobsetevals->[0]->builds->[0]->id or die "Couldn't exec";
}

my $data = [];

until (@{$data}) {
    $data = decode_json(request_json({ uri => "/status"})->content());
}

kill 15, $pid;

foreach my $buildstep (@{$data}) {
    ok(defined $buildstep->{machine}, "Buildsteps have machines");
}
