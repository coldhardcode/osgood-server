package Osgood::Server::Controller::Event;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

use Greenspan::Date;
use Osgood::Event;
use Osgood::EventList;
use Osgood::EventList::Serializer;
use Osgood::EventList::Deserializer;


=head1 NAME

Osgood::Server::Controller::Event - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 list 

=cut

sub list : Local {
	my ($self, $c) = @_;

	# init search hash
	my $search_hash = {};

	# build search hash
	my $join_array = [];
	my $object = $c->req->params->{'object'};
	if (defined($object)) {
		$object =~ s/\'//g;
		$search_hash->{'object.name'} = $object;
		push (@{$join_array}, 'object');
	}
	my $action = $c->req->params->{'action'};
	if (defined($action)) {
		$action =~ s/\'//g;
		$search_hash->{'action.name'} = $action;
		push (@{$join_array}, 'action');
	}
	my $id = $c->req->params->{'id'};
	if (defined($id)) {
		$id =~ s/\'//g;
		$search_hash->{'event_id'} = { '>' => $id};
	}
	my $date = $c->req->params->{'date'};
	if (defined($date)) {
		$date =~ s/\'//g;
		$search_hash->{'event_date'} = { '>' => $date};
	}

	if ((keys %{$search_hash}) <= 0) {
		$c->stash->{error} = "Error no query parameters";
		return;
	}

	my $query = [$search_hash];
	# if set, hook hon join array
	if (scalar @{$join_array} > 0) {
		@{$query}[1] = {'join' => $join_array};
	}

	my $net_list = new Osgood::EventList;
	my $events = $c->model('OsgoodDB::Event')->search(@{$query});
	if (defined($events)) {
		my $count = 0;
		while (my $event = $events->next()) {
			# convert db event to net event
			my $net_event = new Osgood::Event($event->get_hash());
			# add net event to list
			$net_list->add_to_events($net_event);
			$count++;
		}
	} 

	# serialize the list
	my $ser = new Osgood::EventList::Serializer(list => $net_list);
	# set response type
	$c->response->content_type('text/xml');
	# return xml
	$c->response->body($ser->serialize());
}

=head2 show 

take an id and return an event object, in xml

=cut

sub show : Local {
	my ($self, $c, $id) = @_;

	unless ($id) {
		$c->stash->{'error'} = 'No id';
		$c->detach('/event/list');
	}

	my $event = $c->model('OsgoodDB::Event')->find($id);

	# init list
	my $net_list = new Osgood::EventList;
	# convert db event to net event
	my $net_event = new Osgood::Event($event->get_hash());
	# add net event to list
	$net_list->add_to_events($net_event);
	# serialize the list
	my $ser = new Osgood::EventList::Serializer(list => $net_list);
	# set response type
	$c->response->content_type('text/xml');
	# return xml
	$c->response->body($ser->serialize());
}

=head2 add 

 takes an xml event list, inserts each event into the database, and 
 returns the number of events inserted as a confirmation. 
 returns zero if any insert failed.

 Tested with: 
 http://bone:3000/event/add?xml=<eventlist><version>1</version><events><event><object>lauren</object><action>threwup</action><date_occurred>2007-11-12T00:00:00</date_occurred><params><param><name>sally</name><value>3</value></param><param><name>sue</name><value>4</value></param></params></event><event><object>cassanova</object><action>ran</action><date_occurred>2007-11-20T00:00:00</date_occurred></event></events></eventlist>

=cut

sub add : Local {
	my ($self, $c) = @_;

	my $xml = $c->req->param('xml');
	if (!defined($xml)) {
		$c->stash->{error} = "Error: missing parameter: xml list of events";
		$c->stash->{count} = 0;
		return; 
	}

	# wrap the insert in a transaction. if any one fails, they all do
	my $schema = $c->model('OsgoodDB')->schema();
	$schema->txn_begin();

	my $des = new Osgood::EventList::Deserializer(xml => $xml);
	my $eList = $des->deserialize();
	my $iter = $eList->iterator();
	# count events
	my $count = 0;
	my $error = undef;

	while (($iter->has_next()) && (!defined($error))) {
		my $xmlEvent = $iter->next();

		# find or create the action
		my $action = $c->model('OsgoodDB::Action')->find_or_create({
			   	name => $xmlEvent->{action}
			});
		if (!defined($action)) {
			$error = "Error: bad action " . $xmlEvent->{action};
			next;
		}
		# find or create the object
		my $object = $c->model('OsgoodDB::Object')->find_or_create({
			   	name => $xmlEvent->{object}
			});
		if (!defined($object)) {
			$error = "Error: bad object " . $xmlEvent->{object};
			next;
		}
		# create event - this has to be a new thing. no find here. 
		my $dbEvent = $c->model('OsgoodDB::Event')->create({
			action_id => $action->id(),
			object_id => $object->id(),
			event_date => $xmlEvent->{date_occurred}
		});
		if (!defined($dbEvent)) {
			$error = "Error: bad event " . $xmlEvent->{object} . " " . 
					 $xmlEvent->{action} . " " . $xmlEvent->{date_occurred};
			next;
		}
		# add all params
		if (defined($xmlEvent->{params})) {
			foreach my $param_name (keys %{$xmlEvent->{params}}) {
				my $event_param = $c->model('OsgoodDB::EventParameter')->create({
					event_id => $dbEvent->id(),
					name => $param_name,
					value => $xmlEvent->{params}->{$param_name}
				});
				if (!defined($event_param)) {
					$error = "Error: bad event parameter" .  $param_name . 
							 " " .  $xmlEvent->{params}->{$param_name};
				}
			}
		}

		# increment count of inserted events
		$count++;
	}

	
	if (defined($error)) {         # if error, rollback
		$count = 0; # if error, count is zero. nothing inserted.
		$schema->txn_rollback();
	} else {					   # otherwise, commit
		$schema->txn_commit();
	}

	$c->stash->{error} = $error;
	$c->stash->{count} = $count;
}

=head2 default 

=cut

#sub default : Private {
#    my ( $self, $c ) = @_;
#	$c->xmlrpc;
#}

sub index : Private {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Osgood::Server::Controller::Event in Event.');
}



=head1 AUTHOR

Lauren O'Meara

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
