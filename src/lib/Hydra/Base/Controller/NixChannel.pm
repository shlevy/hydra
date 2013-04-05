package Hydra::Base::Controller::NixChannel;

use strict;
use warnings;
use base 'Hydra::Base::Controller::REST';
use List::MoreUtils qw(all);
use Nix::Store;
use Hydra::Helper::Nix;
use Hydra::Helper::CatalystUtils;


sub getChannelData {
    my ($c, $checkValidity) = @_;

    my @storePaths = ();
    $c->stash->{nixPkgs} = [];
    foreach my $build ($c->stash->{channelBuilds}->all) {
        my $outPath = $build->get_column("outpath");
        my $outName = $build->get_column("outname");
        next if $checkValidity && !isValidPath($outPath);
        push @storePaths, $outPath;
        my $pkgName = $build->nixname . "-" . $build->system . "-" . $build->id . ($outName ne "out" ? "-" . $outName : "");
        push @{$c->stash->{nixPkgs}}, { build => $build, name => $pkgName, outPath => $outPath, outName => $outName };
        # Put the system type in the manifest (for top-level paths) as
        # a hint to the binary patch generator.  (It shouldn't try to
        # generate patches between builds for different systems.)  It
        # would be nice if Nix stored this info for every path but it
        # doesn't.
        $c->stash->{systemForPath}->{$outPath} = $build->system;
    };

    $c->stash->{storePaths} = [@storePaths];
}


sub closure : Chained('nix') PathPart : ActionClass('REST') :Args(0) { }

sub closure_HEAD {
    my ($self, $c) = @_;
    $c->response->content_type('application/x-nix-export');
}

sub closure_GET {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'NixClosure';

    getChannelData($c, 1);

    # FIXME: get the closure of the selected path only.
}


sub manifest : Chained('nix') PathPart("MANIFEST") Args(0) : ActionClass('REST') { }

sub manifest_GET {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'NixManifest';
    $c->stash->{narBase} = $c->uri_for($c->controller('Root')->action_for("nar"));
    getChannelData($c, 1);
}


sub pkg : Chained('nix') PathPart Args(1) : ActionClass('REST') {
    my ($self, $c, $pkgName) = @_;

    if (!$c->stash->{build}) {
        unless ($pkgName =~ /-(\d+)\.nixpkg$/) {
            $self->status_not_found($c, message => "Bad package name.");
            return;
        }

        # FIXME: need to handle multiple outputs: channelBuilds is
        # joined with the build outputs, so find() can return multiple
        # results.
        unless($c->stash->{build} = $c->stash->{channelBuilds}->find({ id => $1 })) {
            $self->status_not_found($c, message => "No such package in this channel.");
            return;
        }
    }

    unless (all { isValidPath($_->path) } $c->stash->{build}->buildoutputs->all) {
        $self->status_gone(
            $c,
            message => "Build " . $c->stash->{build}->id . " is no longer available."
        );
    }
}

sub pkg_HEAD {
    my ($self, $c) = @_;
    $c->response->content_type('application/nix-package');
}

sub pkg_GET {
    my ($self, $c) = @_;

    $c->stash->{manifestUri} = $c->uri_for($self->action_for("manifest"), $c->req->captures);

    $c->stash->{current_view} = 'NixPkg';
}


sub nixexprs : Chained('nix') PathPart('nixexprs.tar.bz2') Args(0) : ActionClass('REST') { }

sub nixexprs_GET {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'NixExprs';
    getChannelData($c, 1);
}


sub binary_cache_url : Chained('nix') PathPart('binary-cache-url') Args(0) : ActionClass('REST') { }

sub binary_cache_url_GET {
    my ($self, $c) = @_;
    $c->stash->{'plain'} = { data => $c->uri_for('/') };
    $c->response->content_type('text/plain');
    $c->forward('Hydra::View::Plain');
}


sub name {
    my ($build) = @_;
    return $build->releasename || $build->nixname;
}


sub sortPkgs {
    # Sort by name, then id.
    return sort
      { lc(name($a->{build})) cmp lc(name($b->{build}))
            or $a->{build}->id <=> $b->{build}->id } @_;
}


sub channel_contents : Chained('nix') PathPart('') Args(0) : ActionClass('REST') { }

sub channel_contents_GET {
    my ($self, $c) = @_;
    # Optimistically assume that none of the packages have been
    # garbage-collected.  That should be true for the "latest"
    # channel.
    getChannelData($c, 0);
    $c->stash->{template} = 'channel-contents.tt';
    $self->status_ok (
        $c,
        entity => [map { { %$_, build => { $_->{build}->get_columns } }; } (sortPkgs @{$c->stash->{nixPkgs}})]
    );
}


1;
