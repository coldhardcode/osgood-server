package Osgood::Server::Model::Object;
use strict;

=head1 NAME

Osgood::Server::Model::Object

=head1 DESCRIPTION

Objects are a component of events. The "noun" of the event.

=head1 DATABASE

See 'objects' table for all methods. 

=cut

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('objects');
__PACKAGE__->add_columns(qw/object_id name/);
__PACKAGE__->set_primary_key('object_id');
__PACKAGE__->has_many(events => 'Osgood::Server::Model::Event', 'object_id' );

1;
