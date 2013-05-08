package Hydra::Controller::Jobset;

use strict;
use warnings;
use base 'Hydra::Base::Controller::ListBuilds';
use Hydra::Helper::Nix;
use Hydra::Helper::CatalystUtils;


sub create_jobset :Chained('/project/projectChain') :PathPart('create-jobset') :Args(0) {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    $c->stash->{template} = 'edit-jobset.tt';
    $c->stash->{create} = 1;
    $c->stash->{edit} = 1;
}


sub projectChain :Chained('/') :PathPart('jobset') :CaptureArgs(1) {
    my ($self, $c, $projectName) = @_;

    my $project = $c->model('DB::Projects')->find($projectName);

    $c->stash->{params} = $c->request->data or $c->request->params;

    unless ($project) {
        $self->status_not_found(
            $c,
            message => "Project $projectName doesn't exist."
        );
        $c->detach;
    }

    $c->stash->{project} = $project;
}


sub project :Chained('projectChain') :PathPart('') :Args(0) :ActionClass('REST::ForBrowsers') { }

sub project_POST {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    my $jobsetName = trim $c->stash->{params}->{name};
    my $exprType =
        $c->stash->{params}->{"nixexprpath"} =~ /.scm$/ ? "guile" : "nix";

    if ($jobsetName !~ /^$jobsetNameRE$/) {
        $self->status_bad_request(
            $c,
            message => "Invalid jobset name: ‘$jobsetName’" 
        );
        $c->detach;
    }

    txn_do($c->model('DB')->schema, sub {
        # Note: $jobsetName is validated in updateProject, which will
        # abort the transaction if the name isn't valid.
        my $jobset = $c->stash->{project}->jobsets->create(
            {name => $jobsetName, nixexprinput => "", nixexprpath => "", emailoverride => ""});
        updateJobset($c, $jobset);
    });

    my $uri = $c->uri_for("/jobset",
            $c->stash->{project}->name, $jobsetName);
    if ($c->req->looks_like_browser) {
        $c->res->redirect($uri);
    } else {
        $self->status_created(
            $c,
            location => "$uri",
            entity => { name => $jobsetName, uri => "$uri", type => "jobset" }
        );
    }
}


sub jobsetChain :Chained('projectChain') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $jobsetName) = @_;

    my $project = $c->stash->{project};

    $c->stash->{jobset_} = $project->jobsets->search(
        {"me.name" => $jobsetName},
        {columns => [
          'me.name'
        , 'me.errormsg'
        , 'me.description'
        , 'me.nixexprpath'
        , 'me.nixexprinput'
        , 'me.lastcheckedtime'
        , 'me.triggertime'
        , 'me.enabled'
        , 'me.enableemail'
        , 'me.emailoverride'
        , 'me.keepnr'
        , 'me.project'
        , 'jobsetinputs.name'
        , 'jobsetinputs.type'
        , {'jobsetinputs.jobsetinputalts.value' => 'jobsetinputalts.value'}
        ], join => {jobsetinputs => ['jobsetinputalts']}}
    );

    $c->stash->{jobset} = $c->stash->{jobset_}->single;

    unless ($c->stash->{jobset}) {
        $self->status_not_found(
            $c,
            message => "Jobset $jobsetName doesn't exist."
        );
        $c->detach;
    }
}


sub jobset :Chained('jobsetChain') :PathPart('') :Args(0) :ActionClass("REST::ForBrowsers") { }

sub jobset_GET {
    my ($self, $c) = @_;

    $c->stash->{template} = 'jobset.tt';

    ($c->stash->{latestEval}) = $c->stash->{jobset}->jobsetevals->search({}, { limit => 1, order_by => ["id desc"], columns => [ 'timestamp' ] });

    $self->status_ok(
        $c,
        entity => {
          jobset => $c->stash->{jobset}
          #!!! Should be part of jobset
        , evals => getEvals($self, $c, scalar $c->stash->{jobset}->jobsetevals->search({},{
            columns => [
              'me.id',
	      'jobsetevalmembers.eval',
	      'jobsetevalmembers.build',
              {
                'jobsetevalmembers.build.job.name' => 'job.name'
              , 'jobsetevalmembers.build.logfile' => 'build.logfile'
              , 'jobsetevalmembers.build.finished' => 'build.finished'
              , 'jobsetevalmembers.build.buildStatus' => 'build.buildStatus'
              }
            ],
            collapse => 1,
            join => { jobsetevalmembers => { build => [ 'job' ] } }
          }), 0, 10)
        }
    );
}


sub jobset_PUT {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    txn_do($c->model('DB')->schema, sub {
        updateJobset($c, $c->stash->{jobset});
    });

    if ($c->request->looks_like_browser) {
        $c->res->redirect($c->uri_for($self->action_for("jobset"),
            [$c->stash->{project}->name, $c->stash->{jobset}->name]));
    } else {
        $self->status_ok(
            $c,
            entity => $c->stash->{jobset}
        );
    }
}


sub jobset_DELETE {
    my ($self, $c) = @_;

    $c->stash->{jobset}->delete;
    if ($c->request->looks_like_browser) {
        $c->res->redirect($c->uri_for($c->controller('Project')->action_for("project"), [$c->stash->{project}->name]));
    } else {
        $self->status_no_content($c);
    }
}


sub jobs :Chained('jobsetChain') :PathPart :Args(0) :ActionClass("REST") { }

sub jobs_GET {
    my ($self, $c) = @_;
    $c->stash->{template} = 'jobset-jobs-tab.tt';

    my @activeJobs = ();
    my @inactiveJobs = ();

    (my $latestEval) = $c->stash->{jobset}->jobsetevals->search(
        { hasnewbuilds => 1}, { limit => 1, order_by => ["id desc"] });

    my %seenActiveJobs;
    if (defined $latestEval) {
        foreach my $build ($latestEval->builds->search({}, { order_by => ["job"], select => ["job"] })) {
            my $job = $build->get_column("job");
            if (!defined $seenActiveJobs{$job}) {
                $seenActiveJobs{$job} = 1;
                push @activeJobs, $job;
            }
        }
    }

    foreach my $job ($c->stash->{jobset}->jobs->search({}, { order_by => ["name"] })) {
        if (!defined $seenActiveJobs{$job->name}) {
            push @inactiveJobs, $job->name;
        }
    }

    $self->status_ok(
        $c,
        entity => {
          activeJobs => \@activeJobs,
          inactiveJobs => \@inactiveJobs,
        }
    );
}


sub status :Chained('jobsetChain') :PathPart :Args(0) :ActionClass("REST") { }

sub status_GET {
    my ($self, $c) = @_;
    $c->stash->{template} = 'jobset-status-tab.tt';

    # FIXME: use latest eval instead of iscurrent.

    $c->stash->{systems} =
        [ $c->stash->{jobset}->builds->search({ iscurrent => 1 }, { select => ["system"], distinct => 1, order_by => "system" }) ];

    # status per system
    my @systems = ();
    foreach my $system (@{$c->stash->{systems}}) {
        push(@systems, $system->system);
    }

    my @select = ();
    my @as = ();
    push(@select, "job"); push(@as, "job");
    foreach my $system (@systems) {
        push(@select, "(select buildstatus from Builds b where b.id = (select max(id) from Builds t where t.project = me.project and t.jobset = me.jobset and t.job = me.job and t.system = '$system' and t.iscurrent = 1 ))");
        push(@as, $system);
        push(@select, "(select b.id from Builds b where b.id = (select max(id) from Builds t where t.project = me.project and t.jobset = me.jobset and t.job = me.job and t.system = '$system' and t.iscurrent = 1 ))");
        push(@as, "$system-build");
    }

    $self->status_ok(
        $c,
        entity => [ $c->model('DB')->resultset('ActiveJobsForJobset')->search(
            {},
            { bind => [$c->stash->{project}->name, $c->stash->{jobset}->name]
            , select => \@select
            , as => \@as
            , order_by => ["job"]
            }
        ) ]
    );
}


# Hydra::Base::Controller::ListBuilds needs this.
sub get_builds :Chained('jobsetChain') :PathPart('') :CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->stash->{allBuilds} = $c->stash->{jobset}->builds;
    $c->stash->{jobStatus} = $c->model('DB')->resultset('JobStatusForJobset')
        ->search({}, {bind => [$c->stash->{project}->name, $c->stash->{jobset}->name]});
    $c->stash->{allJobsets} = $c->stash->{jobset_};
    $c->stash->{allJobs} = $c->stash->{jobset}->jobs;
    $c->stash->{latestSucceeded} = $c->model('DB')->resultset('LatestSucceededForJobset')
        ->search({}, {bind => [$c->stash->{project}->name, $c->stash->{jobset}->name]});
    $c->stash->{channelBaseName} =
        $c->stash->{project}->name . "-" . $c->stash->{jobset}->name;
}


sub edit :Chained('jobsetChain') :PathPart :Args(0) :ActionClass("REST") { }

sub edit_GET {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    $c->stash->{template} = 'edit-jobset.tt';
    $c->stash->{edit} = 1;
}


sub nixExprPathFromParams {
    my ($c) = @_;

    # The Nix expression path must be relative and can't contain ".." elements.
    my $nixExprPath = trim $c->stash->{params}->{"nixexprpath"};
    error($c, "Invalid Nix expression path: $nixExprPath") if $nixExprPath !~ /^$relPathRE$/;

    my $nixExprInput = trim $c->stash->{params}->{"nixexprinput"};
    error($c, "Invalid Nix expression input name: $nixExprInput") unless $nixExprInput =~ /^\w+$/;

    return ($nixExprPath, $nixExprInput);
}


sub checkInput {
    my ($c, $baseName) = @_;

    my $inputName = trim $c->stash->{params}->{"input-$baseName-name"};
    error($c, "Invalid input name: $inputName") unless $inputName =~ /^[[:alpha:]]\w*$/;

    my $inputType = trim $c->stash->{params}->{"input-$baseName-type"};
    error($c, "Invalid input type: $inputType") unless
        $inputType eq "svn" || $inputType eq "svn-checkout" || $inputType eq "hg" || $inputType eq "tarball" ||
        $inputType eq "string" || $inputType eq "path" || $inputType eq "boolean" || $inputType eq "bzr" || $inputType eq "bzr-checkout" ||
        $inputType eq "git" || $inputType eq "build" || $inputType eq "sysbuild" ;

    return ($inputName, $inputType);
}


sub checkInputValue {
    my ($c, $type, $value) = @_;
    $value = trim $value;
    error($c, "Invalid Boolean value: $value") if
        $type eq "boolean" && !($value eq "true" || $value eq "false");
    return $value;
}


sub updateJobset {
    my ($c, $jobset) = @_;

    my $jobsetName = trim $c->stash->{params}->{"name"};
    error($c, "Invalid jobset name: ‘$jobsetName’") if $jobsetName !~ /^$jobsetNameRE$/;

    # When the expression is in a .scm file, assume it's a Guile + Guix
    # build expression.
    my $exprType =
        $c->stash->{params}->{"nixexprpath"} =~ /.scm$/ ? "guile" : "nix";

    my ($nixExprPath, $nixExprInput) = nixExprPathFromParams $c;

    $jobset->update(
        { name => $jobsetName
        , description => trim($c->stash->{params}->{"description"})
        , nixexprpath => $nixExprPath
        , nixexprinput => $nixExprInput
        , enabled => defined $c->stash->{params}->{enabled} ? 1 : 0
        , enableemail => defined $c->stash->{params}->{enableemail} ? 1 : 0
        , emailoverride => trim($c->stash->{params}->{emailoverride}) || ""
        , hidden => defined $c->stash->{params}->{visible} ? 0 : 1
        , keepnr => trim($c->stash->{params}->{keepnr}) || 3
        , triggertime => $jobset->triggertime // time()
        });

    my %inputNames;

    # Process the inputs of this jobset.
    # !!! TODO: Make it possible to pass in params like { inputs: { name: {blah} } } for hierarchical content-types (i.e. not multipart/form-data)
    foreach my $param (keys %{$c->stash->{params}}) {
        next unless $param =~ /^input-(\w+)-name$/;
        my $baseName = $1;
        next if $baseName eq "template";

        my ($inputName, $inputType) = checkInput($c, $baseName);

        $inputNames{$inputName} = 1;

        my $input;
        if ($baseName =~ /^\d+$/) { # numeric base name is auto-generated, i.e. a new entry
            $input = $jobset->jobsetinputs->create(
                { name => $inputName
                , type => $inputType
                });
        } else { # it's an existing input
            $input = ($jobset->jobsetinputs->search({name => $baseName}))[0];
            die unless defined $input;
            $input->update({name => $inputName, type => $inputType});
        }

        # Update the values for this input.  Just delete all the
        # current ones, then create the new values.
        $input->jobsetinputalts->delete_all;
        my $values = $c->stash->{params}->{"input-$baseName-values"};
        $values = [] unless defined $values;
        $values = [$values] unless ref($values) eq 'ARRAY';
        my $altnr = 0;
        foreach my $value (@{$values}) {
            $value = checkInputValue($c, $inputType, $value);
            $input->jobsetinputalts->create({altnr => $altnr++, value => $value});
        }
    }

    # Get rid of deleted inputs.
    my @inputs = $jobset->jobsetinputs->all;
    foreach my $input (@inputs) {
        $input->delete unless defined $inputNames{$input->name};
    }
}


sub clone :Chained('jobsetChain') :PathPart :Args(0) :ActionClass("REST") { }

sub clone_GET {
    my ($self, $c) = @_;

    my $jobset = $c->stash->{jobset};
    requireProjectOwner($c, $jobset->project);

    $c->stash->{template} = 'clone-jobset.tt';
}


sub evals :Chained('jobsetChain') :PathPart :Args(0) :ActionClass("REST") { }

sub evals_GET {
    my ($self, $c) = @_;

    $c->stash->{template} = 'evals.tt';

    my $page = int($c->stash->{params}->{page} || "1") || 1;

    my $resultsPerPage = 20;

    my $evals = $c->stash->{jobset}->jobsetevals;

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


# Redirect to the latest finished evaluation of this jobset.
sub latest_eval :Chained('jobsetChain') :PathPart('latest-eval') :ActionClass("REST") { }

sub latest_eval_GET {
    my ($self, $c, @args) = @_;
    my $eval = getLatestFinishedEval($c, $c->stash->{jobset})
        or notFound($c, "No evaluation found.");
    $c->res->redirect($c->uri_for($c->controller('JobsetEval')->action_for("view"), [$eval->id], @args, $c->stash->{params}));
}


1;
