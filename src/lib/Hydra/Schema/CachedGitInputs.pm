use utf8;
package Hydra::Schema::CachedGitInputs;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Hydra::Schema::CachedGitInputs

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

=head1 TABLE: C<CachedGitInputs>

=cut

__PACKAGE__->table("CachedGitInputs");

=head1 ACCESSORS

=head2 uri

  data_type: 'text'
  is_nullable: 0
  is_serializable: 1

=head2 branch

  data_type: 'text'
  is_nullable: 0
  is_serializable: 1

=head2 revision

  data_type: 'text'
  is_nullable: 0
  is_serializable: 1

=head2 sha256hash

  data_type: 'text'
  is_nullable: 0
  is_serializable: 1

=head2 storepath

  data_type: 'text'
  is_nullable: 0
  is_serializable: 1

=cut

__PACKAGE__->add_columns(
  "uri",
  { data_type => "text", is_nullable => 0, is_serializable => 1 },
  "branch",
  { data_type => "text", is_nullable => 0, is_serializable => 1 },
  "revision",
  { data_type => "text", is_nullable => 0, is_serializable => 1 },
  "sha256hash",
  { data_type => "text", is_nullable => 0, is_serializable => 1 },
  "storepath",
  { data_type => "text", is_nullable => 0, is_serializable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</uri>

=item * L</branch>

=item * L</revision>

=back

=cut

__PACKAGE__->set_primary_key("uri", "branch", "revision");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-03-27 16:37:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kgqifBEFsBL5bOe9wlmhgw

1;
