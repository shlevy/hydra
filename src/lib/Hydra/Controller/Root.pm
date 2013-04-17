package Hydra::Controller::Root;

use strict;
use warnings;
use base 'Hydra::Base::Controller::ListBuilds';
use Hydra::Helper::Nix;
use Hydra::Helper::CatalystUtils;
use Digest::SHA1 qw(sha1_hex);
use Nix::Store;
use Nix::Config;
use POSIX;

# Put this controller at top-level.
__PACKAGE__->config->{namespace} = '';


sub begin :Private {
    my ($self, $c, @args) = @_;
    $c->stash->{curUri} = $c->request->uri;
    $c->stash->{version} = $ENV{"HYDRA_RELEASE"} || "<devel>";
    $c->stash->{nixVersion} = $ENV{"NIX_RELEASE"} || "<devel>";
    $c->stash->{curTime} = time;
    $c->stash->{logo} = $ENV{"HYDRA_LOGO"} ? "/logo" : "";
    $c->stash->{tracker} = $ENV{"HYDRA_TRACKER"};
    $c->stash->{flashMsg} = $c->flash->{flashMsg};
    $c->stash->{successMsg} = $c->flash->{successMsg};

    if (scalar(@args) == 0 || $args[0] ne "static") {
        $c->stash->{nrRunningBuilds} = $c->model('DB::Builds')->search({ finished => 0, busy => 1 }, {})->count();
        $c->stash->{nrQueuedBuilds} = $c->model('DB::Builds')->search({ finished => 0 })->count();
    }
    $c->forward('deserialize');
}

sub deserialize :ActionClass('Deserialize') { }


sub index :Path :Args(0) :ActionClass('REST') { }

sub index_GET {
    my ($self, $c) = @_;
    $c->stash->{template} = 'overview.tt';
    $c->stash->{newsItems} = [$c->model('DB::NewsItems')->search({}, { order_by => ['createtime DESC'], rows => 5 })];
    $self->status_ok(
        $c,
        entity => [ $c->model('DB::Projects')->search(
            isAdmin($c) ? {} : {hidden => 0},
            {
                order_by => 'name',
                columns => [ 'enabled', 'hidden', 'name', 'displayname', 'homepage', 'description' ],
            }
        )]
    );
}


sub queue :Local :Args(0) :ActionClass('REST') { }

sub queue_GET {
    my ($self, $c) = @_;
    $c->stash->{template} = 'queue.tt';
    $c->stash->{flashMsg} //= $c->flash->{buildMsg};
    $self->status_ok(
        $c,
        entity => [$c->model('DB::Builds')->search(
            {finished => 0}, { join => ['project'], order_by => ["priority DESC", "timestamp"], columns => [@buildListColumns], '+select' => ['project.enabled'], '+as' => ['enabled'] })]
    );
}


sub queue_DELETE {
    my ($self, $c) = @_;
    requireAdmin($self, $c);
    $c->model('DB::Builds')->search({finished => 0, iscurrent => 0, busy => 0})->update({ finished => 1, buildstatus => 4, timestamp => time});
    $self->status_no_content(
        $c
    );
}


sub timeline :Local :Args(0) {
    my ($self, $c) = @_;
    my $pit = time();
    $c->stash->{pit} = $pit;
    $pit = $pit-(24*60*60)-1;

    $c->stash->{template} = 'timeline.tt';
    $c->stash->{builds} = [ $c->model('DB::Builds')->search
        ( { finished => 1, stoptime => { '>' => $pit } }
        , { order_by => ["starttime"] }
        ) ];
}


sub status :Local :Args(0) :ActionClass('REST') { }

sub status_GET {
    my ($self, $c) = @_;
    $self->status_ok(
        $c,
        entity => [ $c->model('DB::BuildSteps')->search(
            { 'me.busy' => 1, 'build.finished' => 0, 'build.busy' => 1 },
            { join => { build => [ 'project', 'job', 'jobset' ] }
            , columns => [
                'me.machine',
                'me.system',
                'me.stepnr',
                'me.drvpath',
                'me.starttime',
                'build.id',
                {
                  'build.project.name' => 'project.name',
                  'build.jobset.name' => 'jobset.name',
                  'build.job.name' => 'job.name'
                }
              ],
            , order_by => [ 'machine' ]
            }
        ) ]
    );
}


sub machines :Local :Args(0) :ActionClass('REST') { }

sub machines_GET {
    my ($self, $c) = @_;
    my $machines = getMachines;
    my $idles = $c->model('DB::BuildSteps')->search(
            { stoptime => { '!=', undef } },
            { select => [ 'machine', { max => 'stoptime', -as => 'max_stoptime' }], group_by => "machine" });
    while (my $idle = $idles->next) {
        ${$machines}{$idle->machine}{'idle'} = $idle->get_column('max_stoptime');
    }
    $c->stash->{template} = 'machine-status.tt';
    $self->status_ok(
        $c,
        entity => {
            machines => $machines,
            steps => [ $c->model('DB::BuildSteps')->search(
                { finished => 0, 'me.busy' => 1, 'build.busy' => 1, },
                { join => { build => [ 'project', 'job', 'jobset' ] }
                , columns => [
                      'me.machine',
                      'me.system',
                      'me.drvpath',
                      'me.starttime',
                      'build.id',
                      {
                        'build.project.name' => 'project.name',
                        'build.jobset.name' => 'jobset.name',
                        'build.job.name' => 'job.name'
                      }
                  ]
                , order_by => [ 'machine', 'stepnr' ]
                }
            ) ]
        }
    );
}


# Hydra::Base::Controller::ListBuilds needs this.
sub get_builds :Chained('/') :PathPart :CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->stash->{allBuilds} = $c->model('DB::Builds');
    $c->stash->{jobStatus} = $c->model('DB')->resultset('JobStatus');
    $c->stash->{allJobsets} = $c->model('DB::Jobsets');
    $c->stash->{allJobs} = $c->model('DB::Jobs');
    $c->stash->{latestSucceeded} = $c->model('DB')->resultset('LatestSucceeded');
    $c->stash->{channelBaseName} = "everything";
}


sub robots_txt :Path('robots.txt') :Args(0) {
    my ($self, $c) = @_;

    sub uri_for {
        my ($c, $controller, $action, @args) = @_;
        return $c->uri_for($c->controller($controller)->action_for($action), @args)->path;
    }

    sub channelUris {
        my ($c, $controller, $bindings) = @_;
        return
            ( uri_for($c, $controller, 'closure', $bindings, "*")
            , uri_for($c, $controller, 'manifest', $bindings)
            , uri_for($c, $controller, 'pkg', $bindings, "*")
            , uri_for($c, $controller, 'nixexprs', $bindings)
            , uri_for($c, $controller, 'channel_contents', $bindings)
            );
    }

    # Put actions that are expensive or not useful for indexing in
    # robots.txt.  Note: wildcards are not universally supported in
    # robots.txt, but apparently Google supports them.
    my @rules =
        ( uri_for($c, 'Build', 'deps', ["*"])
        , uri_for($c, 'Build', 'view_nixlog', ["*"], "*")
        , uri_for($c, 'Build', 'view_log', ["*"], "*")
        , uri_for($c, 'Build', 'view_log', ["*"])
        , uri_for($c, 'Build', 'download', ["*"], "*")
        , uri_for($c, 'Root', 'nar', [], "*")
        , uri_for($c, 'Root', 'status', [])
        , uri_for($c, 'Root', 'all', [])
        , uri_for($c, 'API', 'scmdiff', [])
        , uri_for($c, 'API', 'logdiff', [],"*", "*")
        , uri_for($c, 'Project', 'all', ["*"])
        , channelUris($c, 'Root', ["*"])
        , channelUris($c, 'Project', ["*", "*"])
        , channelUris($c, 'Jobset', ["*", "*", "*"])
        , channelUris($c, 'Job', ["*", "*", "*", "*"])
        , channelUris($c, 'Build', ["*"])
        );

    $c->stash->{'plain'} = { data => "User-agent: *\n" . join('', map { "Disallow: $_\n" } @rules) };
    $c->stash->{current_view} = 'Hydra::View::Plain';
}


sub default :Path {
    my ($self, $c) = @_;
    $self->status_not_found(
        $c,
        message => "Page not found."
    );
}


sub end :ActionClass('RenderView') {
    my ($self, $c) = @_;

    if (scalar @{$c->error}) {
        $c->stash->{resource} = { errors => $c->error };
        $c->stash->{template} = 'error.tt';
        $c->clear_errors;
        $c->response->status(500) if $c->response->status == 200;
        if ($c->response->status >= 300) {
            $c->stash->{httpStatus} =
                $c->response->status . " " . HTTP::Status::status_message($c->response->status);
        }
    } elsif (defined $c->stash->{resource} and
        (ref $c->stash->{resource} eq ref {}) and
        defined $c->stash->{resource}->{error}) {
        $c->stash->{template} = 'error.tt';
        $c->stash->{httpStatus} =
            $c->response->status . " " . HTTP::Status::status_message($c->response->status);
    }

    $c->forward('serialize');
}

sub serialize : ActionClass('Serialize') {}


sub nar :Local :Args(1) {
    my ($self, $c, $path) = @_;

    $path = ($ENV{NIX_STORE_DIR} || "/nix/store")."/$path";

    if (!isValidPath($path)) {
        $self->status_gone(
            $c,
            message => "Path " . $path . " is no longer available."
        );
    } else {
        $c->stash->{current_view} = 'NixNAR';
        $c->stash->{storePath} = $path;
    }
}


sub nix_cache_info :Path('nix-cache-info') :Args(0) {
    my ($self, $c) = @_;
    $c->response->content_type('text/plain');
    $c->stash->{'plain'} = { data =>
        #"StoreDir: $Nix::Config::storeDir\n" . # FIXME
        "StoreDir: /nix/store\n" .
        "WantMassQuery: 0\n" .
        # Give Hydra binary caches a very low priority (lower than the
        # static binary cache http://nixos.org/binary-cache).
        "Priority: 100\n"
    };
    $c->stash->{current_view} = 'Hydra::View::Plain';
}


sub hashToPath {
    my ($c, $hash) = @_;
    die if length($hash) != 32;
    my $path = queryPathFromHashPart($hash);
    notFound($c, "Store path with hash ‘$hash’ does not exist.") unless $path;
    return $path;
}


sub narinfo :LocalRegex('^([a-z0-9]+).narinfo$') :Args(0) {
    my ($self, $c) = @_;
    my $hash = $c->req->captures->[0];
    $c->stash->{storePath} = hashToPath($c, $hash);
    $c->stash->{current_view} = 'NARInfo';
}


sub logo :Local :Args(0) {
    my ($self, $c) = @_;
    my $path = $ENV{"HYDRA_LOGO"} or die("Logo not set!");
    $c->serve_static_file($path);
}


sub evals :Local :Args(0) :ActionClass('REST') { }

sub evals_GET {
    my ($self, $c) = @_;

    $c->stash->{template} = 'evals.tt';

    my $page = int($c->req->param('page') || "1") || 1;

    my $resultsPerPage = 20;

    my $evals = $c->model('DB::JobsetEvals');

    $c->stash->{resultsPerPage} = $resultsPerPage;
    $c->stash->{page} = $page;
    my $total = $evals->search({hasnewbuilds => 1})->count;
    my %entity = (
        evals => getEvals($self, $c, $evals, ($page - 1) * $resultsPerPage, $resultsPerPage),
        total => $total,
        first => "?page=1",
        last => "?page=" . POSIX::ceil($total/$resultsPerPage)
    );
    if ($page > 1) {
        $entity{previous} = "?page=" . $page - 1;
    }
    if ($page < $entity{last}) {
        $entity{next} = "?page=" . $page + 1;
    }
    $self->status_ok(
        $c,
        entity => \%entity
    );
}


sub search :Local :Args(0) :ActionClass('REST') { }

sub search_POST {
    my ($self, $c) = @_;
    $c->stash->{template} = 'search.tt';

    my $query = trim $c->request->params->{"query"};

    if ($query eq "") {
        $self->status_bad_request(
            $c,
            message => "Query is empty"
        );
    } elsif ($query !~ /^[a-zA-Z0-9_\-]+$/) {
        $self->status_bad_request(
            $c,
            message => "Invalid character in query."
        );
    } else {
        $c->stash->{limit} = 500;

        $self->status_ok(
            $c,
            entity => {
              projects => [ $c->model('DB::Projects')->search(
                  { -and =>
                      [ { -or => [ name => { ilike => "%$query%" }, displayName => { ilike => "%$query%" }, description => { ilike => "%$query%" } ] }
                      , { hidden => 0 }
                      ]
                  },
                  { order_by => ["name"], columns => [ 'enabled', 'name', 'description' ] } ) ],
              jobsets => [ $c->model('DB::Jobsets')->search(
                  { -and =>
                      [ { -or => [ "me.name" => { ilike => "%$query%" }, "me.description" => { ilike => "%$query%" } ] }
                      , { "project.hidden" => 0, "me.hidden" => 0 }
                      ]
                  },
                  {
                      order_by => ["project", "name"],
                      join => ["project"],
                      columns => [ { project_name => "me.project" }, "me.name", "me.enabled", "me.description" ]
                  } ) ],
              jobs => [ $c->model('DB::Jobs')->search(
                  { "me.name" => { ilike => "%$query%" }
                  , "project.hidden" => 0
                  , "jobset.hidden" => 0
                  },
                  { order_by => ["enabled_ desc", "project", "jobset", "name"], join => ["project", "jobset"]
                  , columns => [ { project_name => "me.project", jobset_name => "me.jobset" }, "me.name" ]
                  , "+select" => [\ "(project.enabled = 1 and jobset.enabled = 1 and exists (select 1 from Builds where project = project.name and jobset = jobset.name and job = me.name and iscurrent = 1)) as enabled_"]
                  , "+as" => ["enabled"]
                  , rows => $c->stash->{limit} + 1
                  } ) ]
            }
        );
    }
}


1;
