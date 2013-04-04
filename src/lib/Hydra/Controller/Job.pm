package Hydra::Controller::Job;

use strict;
use warnings;
use base 'Hydra::Base::Controller::ListBuilds';
use Hydra::Helper::Nix;
use Hydra::Helper::CatalystUtils;


sub jobChain :Chained('/') :PathPart CaptureArgs(3) {
    my ($self, $c, $projectName, $jobsetName, $jobName) = @_;

    $c->stash->{job_} = $c->model('DB::Jobs')->search({'me.project' => $projectName, 'me.jobset' => $jobsetName, 'me.name' => $jobName}, {columns => ['me.name', 'project.name', 'jobset.name'], join => [ 'project', 'jobset' ]});
    $c->stash->{job} = $c->stash->{job_}->single;
    unless ($c->stash->{job}) {
        $self->status_not_found(
            $c,
            message => "Job $projectName:$jobsetName:$jobName doesn't exist."
        );
        $c->detach;
    }
    $c->stash->{project} = $c->stash->{job}->project;
    $c->stash->{jobset} = $c->stash->{job}->jobset;
}


sub job :Chained('jobChain') :PathPart('') :Args(0) :ActionClass("REST") { }
sub job_GET {
    my ($self, $c) = @_;

    $c->stash->{template} = 'job.tt';

    $c->stash->{lastBuilds} =
        [ $c->stash->{job}->builds->search({ finished => 1 },
            { order_by => 'timestamp DESC', rows => 10, columns => [@buildListColumns] }) ];

    $c->stash->{queuedBuilds} = [
        $c->stash->{job}->builds->search(
            { finished => 0 },
            { join => ['project']
            , order_by => ["priority DESC", "timestamp"]
            , '+select' => ['project.enabled']
            , '+as' => ['enabled']
            }
        ) ];

    $c->stash->{systems} = [$c->stash->{job}->builds->search({iscurrent => 1}, {select => ["system"], distinct => 1})];
    $self->status_ok(
        $c,
        entity => $c->stash->{job}
    );
}


# Hydra::Base::Controller::ListBuilds needs this.
sub get_builds : Chained('jobChain') PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->stash->{allBuilds} = $c->stash->{job}->builds;
    $c->stash->{jobStatus} = $c->model('DB')->resultset('JobStatusForJob')
        ->search({}, {bind => [$c->stash->{project}->name, $c->stash->{jobset}->name, $c->stash->{job}->name]});
    $c->stash->{allJobs} = $c->stash->{job_};
    $c->stash->{latestSucceeded} = $c->model('DB')->resultset('LatestSucceededForJob')
        ->search({}, {bind => [$c->stash->{project}->name, $c->stash->{jobset}->name, $c->stash->{job}->name]});
    $c->stash->{channelBaseName} =
        $c->stash->{project}->name . "-" . $c->stash->{jobset}->name . "-" . $c->stash->{job}->name;
}


1;
