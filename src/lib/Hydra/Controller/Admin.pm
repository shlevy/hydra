package Hydra::Controller::Admin;

use strict;
use warnings;
use base 'Hydra::Base::Controller::REST';
use Hydra::Helper::Nix;
use Hydra::Helper::CatalystUtils;
use Hydra::Helper::AddBuilds;
use Data::Dump qw(dump);
use Digest::SHA1 qw(sha1_hex);
use Config::General;


sub admin : Chained('/') PathPart('admin') CaptureArgs(0) {
    my ($self, $c) = @_;
    requireAdmin($c);
    $c->stash->{admin} = 1;
}


sub users : Chained('admin') PathPart('users') Args(0) : ActionClass('REST') { }

sub users_GET {
    my ($self, $c) = @_;
    $c->stash->{template} = 'users.tt';
    $self->status_ok(
        $c,
        entity => [$c->model('DB::Users')->search({},{
            order_by => "me.username",
            columns => [ 'me.fullname', 'me.emailonerror', 'me.username', 'me.emailaddress', 'userroles.role' ],
            join => [ 'userroles' ],
        })]
    );
}


sub machines : Chained('admin') PathPart('machines') Args(0) : ActionClass('REST') { }

sub machines_GET {
    my ($self, $c) = @_;
    $c->stash->{template} = 'machines.tt';
    $self->status_ok(
        $c,
        entity => getMachines
    );
}


sub failedcache : Chained('admin') PathPart('failed-cache') Args(0) : ActionClass('REST') { }

sub failedcache_DELETE {
    my ($self, $c) = @_;
    my $r = `nix-store --clear-failed-paths '*'`;
    $self->status_no_content(
        $c
    );
}


sub vcscache : Chained('admin') PathPart('vcs-cache') Args(0) : ActionClass('REST') { }

sub vcscache_DELETE {
    my ($self, $c) = @_;

    print "Clearing path cache\n";
    $c->model('DB::CachedPathInputs')->delete_all;

    print "Clearing git cache\n";
    $c->model('DB::CachedGitInputs')->delete_all;

    print "Clearing subversion cache\n";
    $c->model('DB::CachedSubversionInputs')->delete_all;

    print "Clearing bazaar cache\n";
    $c->model('DB::CachedBazaarInputs')->delete_all;

    $self->status_no_content(
        $c
    );
}


sub news : Chained('admin') PathPart('news') Args(0) : ActionClass('REST::ForBrowsers') { }

sub news_GET {
    my ($self, $c) = @_;

    $c->stash->{template} = 'news.tt';
    $self->status_ok(
        $c,
        entity => [$c->model('DB::NewsItems')->search({}, {order_by => 'createtime DESC'})]
    );
}


sub news_POST {
    my ($self, $c) = @_;

    my $contents = trim $c->request->params->{"contents"};
    my $createtime = time;

    my %newsItem = $c->model('DB::NewsItems')->create({
        createtime => $createtime,
        contents => $contents,
        author => $c->user->username
    })->get_columns;

    if ($c->req->looks_like_browser) {
        $c->res->redirect("/admin/news");
    } else {
        $self->status_created(
            $c,
            location => $c->req->uri . "/" . $newsItem{id},
            entity => { id => $newsItem{id}, uri => $c->req->uri . "/" . $newsItem{id}, type => "news-item" }
        );
    }
}

sub news_item : Chained('admin') PathPart('news') Args(1) : ActionClass('REST::ForBrowsers') { }

sub news_item_GET : {
    my ($self, $c, $id) = @_;
    my $newsItem = $c->model('DB::NewsItems')->find($id,
        { result_class =>'DBIx::Class::ResultClass::HashRefInflator' }
    );
    if (defined $newsItem) {
        $self->status_ok (
            $c,
            entity => $newsItem
        );
    } else {
        $self->status_not_found(
            $c,
            message => "News item with id $id doesn't exist."
        );
    }
}


sub news_item_DELETE : {
    my ($self, $c, $id) = @_;

    txn_do($c->model('DB')->schema, sub {
        my $newsItem = $c->model('DB::NewsItems')->find($id);
        if (defined $newsItem) {
            $newsItem->delete;
            if ($c->req->looks_like_browser) {
		 $c->res->redirect("/admin/news");
            } else {
                $self->status_no_content(
                    $c
                );
            }
        } else {
          self->status_not_found($c, message => "News item with id $id doesn't exist.");
        }
    });
}


1;
