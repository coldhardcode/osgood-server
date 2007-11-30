package Osgood::Server::Controller::Event;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

use DateTime::Format::MySQL;
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

Takes one or more query parameters and returns a list of events.  Parameters can be: 

=over 

=item "id"

looks for all events with id greater than this number

=item "date"

looks for all events with date greater than this date

=item "object"

looks for all events with this object

=item "action"

looks for all events with this action

=back 

If fields are invalid, an error is returned. If no matching events are found, an emtpy list is returned. 

=cut

sub list : Local {
	my ($self, $c) = @_;

	# make sure there are parameters
	if ((keys %{$c->req->params}) <= 0) {
		$c->stash->{error} = "Error no query parameters";
		return;
	}

	# init resultset 
	my $events = $c->model('OsgoodDB')->schema()->resultset('Event');

	# order query by event_id
	$events = $events->search( undef, {order_by => 'event_id' } );

	# build search hash
	my $object = $c->req->params->{'object'};
	if (defined($object)) {
		$object =~ s/\'//g;
		$events = $events->search(
			{'object.name' => $object}, 
			{'join' => 'object'}
		);
	}
	my $action = $c->req->params->{'action'};
	if (defined($action)) {
		$action =~ s/\'//g;
		$events = $events->search(
			{'action.name' => $action}, 
			{'join' => 'action'}
		);
	}
	my $id = $c->req->params->{'id'};
	if (defined($id)) {
		$id =~ s/\'//g;
		$events = $events->search( {'event_id' => { '>' => $id } } );
	}
	my $date = $c->req->params->{'date'};
	if (defined($date)) {
		$date =~ s/\'//g;
		$events = $events->search( {'date_occurred' => { '>' => $date } } );
	}
	my $limit = $c->req->params->{'limit'};
	if (defined($limit)) {
		$limit =~ s/\'//g;
		$events = $events->search( undef, { rows => $limit } );
	}

	my $net_list = new Osgood::EventList;
	if (defined($events)) {
		while (my $event = $events->next()) {
			# convert db event to net event
			my $net_event = new Osgood::Event($event->get_hash());
			# add net event to list
			$net_list->add_to_events($net_event);
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

Takes an id and returns an event list containing the matching event.

=cut

sub show : Local {
	my ($self, $c, $id) = @_;

	#FIXME - why'd i do this?
	unless ($id) {
		$c->stash->{'error'} = 'No id';
		$c->detach('/event/list');
	}

	my $event = $c->model('OsgoodDB::Event')->find($id);

	# init list
	my $net_list = new Osgood::EventList;

	if (defined($event)) {
		# convert db event to net event
		my $net_event = new Osgood::Event($event->get_hash());
		# add net event to list
		$net_list->add_to_events($net_event);
	}

	# serialize the list
	my $ser = new Osgood::EventList::Serializer(list => $net_list);
	# set response type
	$c->response->content_type('text/xml');
	# return xml
	$c->response->body($ser->serialize());
}

=head2 add 

Takes an xml event list. Inserts each event into the database, and 
returns the number of events inserted as a confirmation. 
Rolls back all changes and returns zero if any insert failed.

=cut

#Tested with: 
# http://bone:3000/event/add?xml=<eventlist><version>1</version><events><event><object>lauren</object><action>threwup</action><date_occurred>2007-11-12T00:00:00</date_occurred><params><param><name>sally</name><value>3</value></param><param><name>sue</name><value>4</value></param></params></event><event><object>cassanova</object><action>ran</action><date_occurred>2007-11-20T00:00:00</date_occurred></event></events></eventlist>

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
			   	name => $xmlEvent->action()
			});
		if (!defined($action)) {
			$error = "Error: bad action " . $xmlEvent->action();
			next;
		}
		# find or create the object
		my $object = $c->model('OsgoodDB::Object')->find_or_create({
			   	name => $xmlEvent->object()
			});
		if (!defined($object)) {
			$error = "Error: bad object " . $xmlEvent->object();
			next;
		}
		# create event - this has to be a new thing. no find here. 
		my $dbEvent = $c->model('OsgoodDB::Event')->create({
			action_id => $action->id(),
			object_id => $object->id(),
			date_occurred => $xmlEvent->date_occurred()
		});
		if (!defined($dbEvent)) {
			$error = "Error: bad event " . $xmlEvent->object() . " " . 
					 $xmlEvent->action() . " " . $xmlEvent->date_occurred();
			next;
		}
		# add all params
		my $params = $xmlEvent->params();
		if (defined($params)) {
			foreach my $param_name (keys %{$params}) {
				my $event_param = $c->model('OsgoodDB::EventParameter')->create({
					event_id => $dbEvent->id(),
					name => $param_name,
					value => $params->{$param_name}
				});
				if (!defined($event_param)) {
					$error = "Error: bad event parameter" .  $param_name . 
							 " " .  $params->{$param_name};
				}
			}
		}

		# increment count of inserted events
		$count++;
	}

	
	if (defined($error)) {         # if error, rollback
		$count = 0; # if error, count is zero. nothing inserted.
		$schema->txn_rollback();
		$c->stash->{error} = $error;
	} else {					   # otherwise, commit
		$schema->txn_commit();
	}

	$c->stash->{count} = $count;
}

=head2 add 

Returns confirmation of controller.

=cut

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
