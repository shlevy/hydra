use utf8;
package Hydra::Schema::ProjectMembers;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Hydra::Schema::ProjectMembers

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::Helper::Row::ToJSON>

=back

=cut

__PACKAGE__->load_components("Helper::Row::ToJSON");

=head1 TABLE: C<ProjectMembers>

=cut

__PACKAGE__->table("ProjectMembers");

=head1 ACCESSORS

=head2 project

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0
  is_serializable: 1

=head2 username

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0
  is_serializable: 1

=cut

__PACKAGE__->add_columns(
  "project",
  {
    data_type       => "text",
    is_foreign_key  => 1,
    is_nullable     => 0,
    is_serializable => 1,
  },
  "username",
  {
    data_type       => "text",
    is_foreign_key  => 1,
    is_nullable     => 0,
    is_serializable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</project>

=item * L</username>

=back

=cut

__PACKAGE__->set_primary_key("project", "username");

=head1 RELATIONS

=head2 project

Type: belongs_to

Related object: L<Hydra::Schema::Projects>

=cut

__PACKAGE__->belongs_to(
  "project",
  "Hydra::Schema::Projects",
  { name => "project" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 username

Type: belongs_to

Related object: L<Hydra::Schema::Users>

=cut

__PACKAGE__->belongs_to(
  "username",
  "Hydra::Schema::Users",
  { username => "username" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-03-27 16:37:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:v2H4UPzx7BwIO7m9suM47g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
