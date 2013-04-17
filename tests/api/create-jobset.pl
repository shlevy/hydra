use strict;
use Setup;
use JSON;
use URI;

use Test::Simple tests => 2;

login();

my $res = request_json({ uri => "/jobset/tests", method => "POST", data => {
    name => "api-3",
    nixexprpath => "foo/bar.nix",
    nixexprinput => "baz",
    enabled => "1",
    visible => "1",
    "input-1-name" => "baz",
    "input-1-type" => "path",
    "input-1-values" => "/home/bang/baz-src"
  } });

ok($res->code() == 201, "Creating a jobset causes it to be Created");

my $uri = URI->new($res->header("Location"));
ok($uri->path() eq "/jobset/tests/api-3", "Creating a jobset named api-3 in project tests creates a resource at /jobset/tests/api-3");
