package Hydra::Base::Controller::REST;

use strict;
use warnings;
use base 'Catalyst::Controller::REST';

__PACKAGE__->config(
    map => {
        'text/html' => [ 'View', 'TT' ]
    },
    'stash_key' => 'resource',
);

1;
