use strict;
use LWP::UserAgent;

system("hydra-server &");

my $ua = LWP::UserAgent->new;

while (1) {
    my $req = HTTP::Request->new(GET => 'http://localhost:3000');
    $req->header(Accept => "text/html");
    my $res = $ua->request($req);
    if ($res->is_success) {
        last;
    }
}

my $failed = 0;
foreach my $test (split(" ",$ENV{API_TESTS})) {
    system("perl -w $test") == 0 or $failed = 1;
}

if ($failed) {
    exit 1;
}
