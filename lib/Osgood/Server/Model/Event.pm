package Osgood::Server::Model::Event;
use strict;

=head1 NAME

Osgood::Server::Model::Event

=head1 DESCRIPTION

Events consist of an action, object, and date. Optionally, it may also include pparameters.

=head1 DATABASE

See 'events' table for all methods. 

=cut

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('events');
__PACKAGE__->add_columns(qw/event_id object_id action_id event_date/);
__PACKAGE__->set_primary_key('event_id');
__PACKAGE__->has_many(parameters => 'Osgood::Server::Model::EventParameter', 'event_id' );
__PACKAGE__->add_relationship('object', 'Osgood::Server::Model::Object', 
	{'foreign.object_id', 'self.object_id'}, 
	{'accessor' => 'single'}
);
__PACKAGE__->add_relationship('action', 'Osgood::Server::Model::Action', 
	{'foreign.action_id', 'self.action_id'}, 
	{'accessor' => 'single'}
);
__PACKAGE__->inflate_column('event_date', { 
	inflate => sub { Greenspan::Date->from_mysql(shift()) },
	deflate => sub { Greenspan::Date->to_mysql(shift()) },
});

sub get_hash {
	my $self = shift;
	my $self_hash = ();

    # stash the event
    $self_hash->{'event_id'} = $self->id();
	$self_hash->{'event_date'} = $self->event_date->ymd;
	$self_hash->{'object'} = $self->object->name();
	$self_hash->{'action'} = $self->action->name();
	$self_hash->{'params'} = ();

	my $params = $self->parameters();
	# iterate over parameters
	while (my $param = $params->next()) {
		push(@{$self_hash->{'params'}},
				{ name => $param->name(),
				  value => $param->value()}
		);
	}

	return $self_hash;
}

1;
