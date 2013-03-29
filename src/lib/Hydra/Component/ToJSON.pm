use utf8;
package Hydra::Component::ToJSON;

use strict;
use warnings;

use base 'DBIx::Class';

sub TO_JSON {
    my $self = shift;
    return $self->get_inflated_columns;
}

1;
