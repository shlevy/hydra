package Hydra::Controller::Project;

use strict;
use warnings;
use base 'Hydra::Base::Controller::ListBuilds';
use Hydra::Helper::Nix;
use Hydra::Helper::CatalystUtils;


sub projects :Path('/project') :ActionClass('REST::ForBrowsers') { }

sub projects_POST {
    my ($self, $c) = @_;

    requireMayCreateProjects($self, $c);

    my $projectName = trim $c->request->params->{name};

    if ($projectName !~ /^$projectNameRE$/) {
        $self->status_bad_request(
            $c,
            message => "Invalid project name: ‘$projectName’" 
        );
    } else {
        txn_do($c->model('DB')->schema, sub {
            # Note: $projectName is validated in updateProject,
            # which will abort the transaction if the name isn't
            # valid.  Idem for the owner.
            my $owner = $c->check_user_roles('admin')
                ? trim $c->request->params->{owner} : $c->user->username;
            my $project = $c->model('DB::Projects')->create(
                {name => $projectName, displayname => "", owner => $owner});
            updateProject($c, $project);
        });

        my $uri = $c->uri_for($self->action_for("project"), [$projectName]);
        if ($c->req->looks_like_browser) {
            $c->res->redirect($uri);
        } else {
            $self->status_created(
                $c,
                location => $uri,
                entity => { name => $projectName, uri => $uri, type => "project" }
            );
        }
    }
}


sub projectChain :Chained('/') :PathPart('project') :CaptureArgs(1) {
    my ($self, $c, $projectName) = @_;

    my $project = $c->model('DB::Projects')->find($projectName, { columns => [
      "me.name",
      "me.displayName",
      "me.description",
      "me.enabled",
      "me.hidden",
      "me.homepage",
      "owner.userName",
      "owner.fullName",
      "views.name",
      "releases.name",
      "releases.timestamp",
    ], join => [ 'owner', 'views', 'releases' ], order_by => { -desc => "releases.timestamp" } });

    if ($project) {
        $c->stash->{project} = $project;
    }
    else {
        $self->status_not_found(
            $c,
            message => "Project $projectName doesn't exist."
        );
        $c->detach;
    }
}


sub project :Chained('projectChain') :PathPart('') :ActionClass('REST::ForBrowsers') { }

sub project_GET {
    my ($self, $c, $projectName) = @_;

    $self->status_ok(
        $c,
        entity => {
          project => $c->stash->{project},
          #!!! Fixme: Want to JOIN this with the projects query
          jobsets => $c->stash->{project}->jobsets->search(isProjectOwner($c, $c->stash->{project}) ? {} : { hidden => 0 },
            { order_by => "name"
            , "columns" => [ {
                nrscheduled => "(select count(*) from Builds as a where a.finished = 0 and me.project = a.project and me.name = a.jobset and a.isCurrent = 1)"
              , nrfailed => "(select count(*) from Builds as a where a.finished = 1 and me.project = a.project and me.name = a.jobset and buildstatus <> 0 and a.isCurrent = 1)"
              , nrsucceeded => "(select count(*) from Builds as a where a.finished = 1 and me.project = a.project and me.name = a.jobset and buildstatus = 0 and a.isCurrent = 1)"
              , nrtotal => "(select count(*) from Builds as a where me.project = a.project and me.name = a.jobset and a.isCurrent = 1)"
              }, "enabled", "hidden", "name", "description", "lastcheckedtime" ]
            }),
        }
    );
}

sub project_PUT {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    txn_do($c->model('DB')->schema, sub {
        updateProject($c, $c->stash->{project});
    });

    if ($c->req->looks_like_browser) {
      $c->res->redirect($c->uri_for($self->action_for("view"), [$c->stash->{project}->name]));
    } else {
        $self->status_ok(
            $c,
            entity => $c->stash->{project}
        );
    }
}

sub project_DELETE {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    $c->stash->{project}->delete;

    if ($c->req->looks_like_browser) {
        $c->res->redirect($c->uri_for("/"));
    } else {
        $self->status_no_content($c);
    }
}

sub edit :Chained('projectChain') :PathPart :Args(0) :ActionClass('REST') { }

sub edit_GET {
    my ($self, $c) = @_;

    requireProjectOwner($c, $c->stash->{project});

    $c->stash->{template} = 'edit-project.tt';
    $c->stash->{edit} = 1;
}


sub requireMayCreateProjects {
    my ($self, $c) = @_;

    requireLogin($c) if !$c->user_exists;

    unless ($c->check_user_roles('admin') || $c->check_user_roles('create-projects')) {
        $self->status_forbidden(
            $c,
            message => "Only administrators or authorised users can perform this operation."
        );
        $c->detach;
    }
}


sub create :Path('/create-project') :ActionClass('REST') { }

sub create_GET {
    my ($self, $c) = @_;

    requireMayCreateProjects($self, $c);

    $c->stash->{template} = 'edit-project.tt';
    $c->stash->{create} = 1;
    $c->stash->{edit} = 1;
}


sub updateProject {
    my ($c, $project) = @_;

    my $owner = $project->owner;
    if ($c->check_user_roles('admin')) {
        $owner = trim $c->request->params->{owner};
        error($c, "Invalid owner: $owner")
            unless defined $c->model('DB::Users')->find({username => $owner});
    }

    my $projectName = trim $c->request->params->{name};
    error($c, "Invalid project name: ‘$projectName’") if $projectName !~ /^$projectNameRE$/;

    my $displayName = trim $c->request->params->{displayname};
    error($c, "Invalid display name: $displayName") if $displayName eq "";

    $project->update(
        { name => $projectName
        , displayname => $displayName
        , description => trim($c->request->params->{description})
        , homepage => trim($c->request->params->{homepage})
        , enabled => defined $c->request->params->{enabled} ? 1 : 0
        , hidden => defined $c->request->params->{visible} ? 0 : 1
        , owner => $owner
        });
}


# Hydra::Base::Controller::ListBuilds needs this.
sub get_builds : Chained('project') PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->stash->{allBuilds} = $c->stash->{project}->builds;
    $c->stash->{jobStatus} = $c->model('DB')->resultset('JobStatusForProject')
        ->search({}, {bind => [$c->stash->{project}->name]});
    $c->stash->{allJobsets} = $c->stash->{project}->jobsets;
    $c->stash->{allJobs} = $c->stash->{project}->jobs;
    $c->stash->{latestSucceeded} = $c->model('DB')->resultset('LatestSucceededForProject')
        ->search({}, {bind => [$c->stash->{project}->name]});
    $c->stash->{channelBaseName} = $c->stash->{project}->name;
}


1;
