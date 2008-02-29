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

use DateTime::TimeZone;

my $tz = new DateTime::TimeZone(name => 'local');

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('events');
__PACKAGE__->add_columns(
		event_id      => {data_type => 'bigint', is_auto_increment => 1},
		object_id     => {data_type => 'bigint', is_foreign_key => 1},
		action_id     => {data_type => 'bigint', is_foreign_key => 1},
		date_occurred => {data_type => 'datetime' }
	);
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
__PACKAGE__->inflate_column('date_occurred', {
	inflate => sub {
		my $str = shift();
		unless($str) {
			return undef;
		}
		my $dt = DateTime::Format::MySQL->parse_datetime($str);
		if(defined($dt)) {
			$dt->set_time_zone($tz);
		} else {
			return undef;
		}
	},
	deflate => sub {
		my $dt = shift();

		if(defined($dt)) {
        	return DateTime::Format::MySQL->format_datetime($dt);
    	} else {
			return undef;
		}
	}
});

sub get_hash {
	my $self = shift;
	my $self_hash = ();

    # stash the event
    $self_hash->{'id'} = $self->id();
	$self_hash->{'date_occurred'} = $self->date_occurred();
	$self_hash->{'object'} = $self->object->name();
	$self_hash->{'action'} = $self->action->name();
	$self_hash->{'params'} = {};

	my $params = $self->parameters();
	# iterate over parameters and add to param hash
	while (my $param = $params->next()) {
		$self_hash->{'params'}->{$param->name()} = $param->value();
	}

	return $self_hash;
}

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Magazines.com, LLC

You can redistribute and/or modify this code under the same terms as Perl
itself.

=cut
1;
