use strict;
use LWP::UserAgent;

system("DBIC_TRACE=1 hydra-server -d &");

my $ua = LWP::UserAgent->new;

while (1) {
    my $req = HTTP::Request->new(GET => 'http://localhost:3000');
    $req->header(Accept => "text/html");
    my $res = $ua->request($req);
    if ($res->is_success) {
        last;
    }
}

my @pids = ();
foreach my $test (split(" ",$ENV{API_TESTS})) {
    my $pid = fork();
    die "Couldn't fork" unless defined $pid;
    if ($pid == 0) {
      exec("perl -w $test") or die "Couldn't exec";
    }
    push @pids, $pid;
}

my $failed = 0;
foreach my $pid (@pids) {
    waitpid($pid, 0) == $pid or die "Couldn't wait";
    $failed = 1 unless $? == 0;
}

if ($failed) {
    exit 1;
}
