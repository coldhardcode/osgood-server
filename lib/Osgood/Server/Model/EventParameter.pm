package Osgood::Server::Model::EventParameter;
use strict;

=head1 NAME

Osgood::Server::Model::EventParameter

=head1 DESCRIPTION

EventParameters are optional components of an event.

=head1 DATABASE

See 'event_parameters' table for all methods. 

=cut

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('event_parameters');
__PACKAGE__->add_columns(qw/event_parameter_id event_id name value/);
__PACKAGE__->set_primary_key('event_parameter_id');

1;
