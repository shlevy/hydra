use strict;
use Setup;
use JSON;
use URI;

use Test::Simple tests => 3;

my $jobset = createBaseJobset("api-4", "basic.nix");
evalSucceeds($jobset);

my $data = decode_json(request_json({ uri => "/jobset/tests/api-4"})->content());

foreach my $eval (@{$data->{evals}}) {
    my $has_empty = 0;
    my $has_fails = 0;
    my $has_succeed_with_fail = 0;
    foreach my $jobsetevalmember (@{$eval->{eval}->{jobsetevalmembers}}) {
        my $name = $jobsetevalmember->{build}->{job}->{name};
        if ($name eq "empty_dir") {
            $has_empty = 1;
        } elsif ($name eq "fails") {
            $has_fails = 1;
        } elsif ($name eq "succeed_with_failed") {
            $has_succeed_with_fail = 1;
        }
    }
    ok($has_empty, "The basic jobset has the empty_dir job");
    ok($has_fails, "The basic jobset has the fails job");
    ok($has_succeed_with_fail, "The basic jobset has the fails job");
}
