package Osgood::Server::Controller::Event;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

use Greenspan::Date;
use Osgood::Event;
use Osgood::EventList;
use Osgood::EventList::Serializer;


=head1 NAME

Osgood::Server::Controller::Event - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 list 

=cut

#FIXME complete this function
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

		#FIXME - would be better if serializer could handle null list 
		#FIXME - also doesn't client want record id? i'm returning it, 
		#    but it's not appearing in the xml output
		if ($count > 0) {
			# serialize the list
			my $ser = new Osgood::EventList::Serializer(list => $net_list);
			# set response type
			$c->response->content_type('text/xml');
			# return xml
			$c->response->body($ser->serialize());
		}
	} 
	#FIXME would prefer to move serialize down here, and deal with null list
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

	#FIXME - will capture this in a function
	# how to wrap so query returns EventList?
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

 an event list looks like: 
 [
	{
		action => <action_name>,
		object => <object_name>,
		event_date => <date>,
		params => [
			{
				name=> <param_name>,
				value=> <param_value>
			}
		]
	}
 ]

used these for testing

 > XMLRPCsh.pl http://127.0.0.1:3000/event
 > event.add([{'action'=>'go there', 'object' => 'thing', 'event_date' => '2007-10-01'}])
 > event.add([{'action'=>'change address', 'object'=>'customer', 'event_date'=>'2007-09-09', 'params' => [{'name'=>'street', 'value'=>'123 street st'}, {'name'=>'country', 'value'=>'US'}]}])

=cut

sub add : XMLRPC {
	my ($self, $c, $list) = @_;

	if (!defined($list)) {
		return { num_events => 0,
			     error => "Error: missing parameter: list of events"};
	}

	if (ref($list) ne 'ARRAY') {
		return { num_events => 0,
			     error => "Error: bad format: list of events"};
	}

	my $schema = $c->model('OsgoodDB')->schema();
	# wrap the insert in a transaction. if any one fails, they all do
	$schema->txn_begin();
	foreach my $item (@{$list}) {
		# find or create the action
		#FIXME - do item validation here. nicer.
		if (!defined($item->{action})) {
			$schema->txn_rollback();
			return { num_events => 0,
				     error => "Error: missing action", 
				     event => $item };
		}
		my $action = $c->model('OsgoodDB::Action')->find_or_create({
			   	name => $item->{action}
			});
		if (!defined($action)) {
			$schema->txn_rollback();
			return { num_events => 0,
				     error => "Error: bad action", 
				     event => $item };
		}
		# find or create the object
		my $object = $c->model('OsgoodDB::Object')->find_or_create({
			   	name => $item->{object}
			});
		if (!defined($object)) {
			$schema->txn_rollback();
			return { num_events => 0,
				     error => "Error: bad object", 
				     event => $item };
		}
		my $event = $c->model('OsgoodDB::Event')->create({
			action_id => $action->id(),
			object_id => $object->id(),
			event_date => $item->{event_date}
		});
		if (!defined($event)) {
			$schema->txn_rollback();
			return { num_events => 0,
				     error => "Error: bad event", 
				     event => $item };
		}
		foreach my $param (@{$item->{params}}) {
			my $event_param = $c->model('OsgoodDB::EventParameter')->create({
				event_id => $event->id(),
				name => $param->{name},
				value => $param->{value}
			});
			if (!defined($event_param)) {
				$schema->txn_rollback();
				return { num_events => 0,
						 error => "Error: bad event parameter", 
					     event => $item };
			}
		}
	}
	$schema->txn_commit();

	return { 'num_events' => scalar(@{$list})};
}

=head2 default 

=cut

sub default : Private {
    my ( $self, $c ) = @_;
	$c->xmlrpc;
}

#sub index : Private {
#    my ( $self, $c ) = @_;
#
#    $c->response->body('Matched Osgood::Server::Controller::Event in Event.');
#}



=head1 AUTHOR

Lauren O'Meara

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
