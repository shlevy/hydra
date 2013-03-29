use utf8;
package Hydra::Schema::SchemaVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Hydra::Schema::SchemaVersion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<Hydra::Component::ToJSON>

=back

=cut

__PACKAGE__->load_components("+Hydra::Component::ToJSON");

=head1 TABLE: C<SchemaVersion>

=cut

__PACKAGE__->table("SchemaVersion");

=head1 ACCESSORS

=head2 version

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns("version", { data_type => "integer", is_nullable => 0 });


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-03-29 08:59:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TWJ+5shm+ChnvwCD5KtVfQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
