use utf8;
package Hydra::Schema::UserRoles;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Hydra::Schema::UserRoles

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

=head1 TABLE: C<UserRoles>

=cut

__PACKAGE__->table("UserRoles");

=head1 ACCESSORS

=head2 username

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0
  is_serializable: 1

=head2 role

  data_type: 'text'
  is_nullable: 0
  is_serializable: 1

=cut

__PACKAGE__->add_columns(
  "username",
  {
    data_type       => "text",
    is_foreign_key  => 1,
    is_nullable     => 0,
    is_serializable => 1,
  },
  "role",
  { data_type => "text", is_nullable => 0, is_serializable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</username>

=item * L</role>

=back

=cut

__PACKAGE__->set_primary_key("username", "role");

=head1 RELATIONS

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aK2Pf/BsZ1capPoDmG+1+w

1;
