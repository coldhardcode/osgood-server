package Osgood::Server::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller::REST';

use DBIx::Class::ResultClass::HashRefInflator;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Osgood::Server::Controller::Root - Root Controller for Osgood::Server

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub default : Private {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body( $c->welcome_message );
}

sub event : Local : ActionClass('REST') { }

=head2 event_GET

=cut

sub event_GET {
my ($self, $c) = @_;

    # make sure there are parameters
    if ((keys %{$c->req->params}) <= 0) {
        $c->stash->{error} = "Error no query parameters";
        return;
    }

    # init resultset 
    my $events = $c->model('OsgoodDB')->schema->resultset('Event');

    # order query by event_id
    $events = $events->search( undef, {prefetch => [ 'parameters', 'action', 'object' ], order_by => 'me.event_id' } );

    my $params = $c->req->params;
    foreach my $param (keys(%{ $params })) {
        if($events->can($param)) {
            $events = $events->$param($params->{$param});
        }
    }
    my $evtparams = $c->req->params->{'parameter'};
    if (defined($evtparams)) {
        my $pnum = 1;
        foreach my $key (keys %$evtparams) {
            $events = $events->search({
                "ep$pnum.name" => $key,
                "ep$pnum.value" => $evtparams->{$key}
            });
            $pnum++;
        }
        $events = $events->search(undef, {
            from => [
                { 'me' => 'events' },
                map {[
                    { "ep$_" => 'event_parameters' },
                    { "ep$_.event_id" => 'me.event_id' }
                    ]} 1 .. $pnum - 1
            ]
        });
    }

    $events->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $limit = $c->req->params->{'limit'};
    my $net_list = Osgood::EventList->new;
    my $count = 0;
    if (defined($events)) {
            while (my $event = $events->next) {
            # Enforce limit this way, as prefetch breaks SQL limit
            if (defined($limit) && $limit <= $count) {
                $events = $events->search( undef, { rows => $limit } );
            }
            # convert db event to net event
            my $params = {};
            if(scalar($event->{'parameters'})) {
                foreach (@{ $event->{'parameters'} }) {
                    $params->{$_->{'name'}} = $_->{'value'};
                }
            }

            my $net_event = Osgood::Event->new(
                id    => $event->{'event_id'},
                object    => $event->{'object'}->{'name'},
                action    => $event->{'action'}->{'name'},
                date_occurred => DateTime::Format::MySQL->parse_datetime($event->{'date_occurred'}),
                params    => $params
            );
            # add net event to list
            $net_list->add_to_events($net_event);
            $count++;
        }
    }

    # set response type
    $c->response->content_type('application/json');
    # return serialized list
    $c->response->body($net_list->freeze);
}

=head2 event_POST

=cut
sub event_POST {
    my ($self, $c) = @_;

	# wrap the insert in a transaction. if any one fails, they all do
    # my $schema = $c->model('OsgoodDB')->schema;
    # $schema->txn_begin;

    my $events = $c->req->data;

    my $list = Osgood::EventList->unpack($events);
    # my $iter = $list->iterator;
    # # count events
    # my $count = 0;
    # my $error = undef;
    # 
    # while (($iter->has_next) && (!defined($error))) {
    #     my $event = $iter->next;
    # 
    #     # find or create the action
    #     my $action = $c->model('OsgoodDB::Action')->find_or_create({
    #         name => $event->action
    #     });
    #     if (!defined($action)) {
    #         $error = "Error: bad action " . $event->action();
    #         last;
    #     }
    #     # find or create the object
    #     my $object = $c->model('OsgoodDB::Object')->find_or_create({
    #         name => $event->object
    #     });
    #     if (!defined($object)) {
    #         $error = "Error: bad object " . $event->object;
    #         last;
    #     }
    #     # create event - this has to be a new thing. no find here. 
    #     my $db_event = $c->model('OsgoodDB::Event')->create({
    #         action_id => $action->id,
    #         object_id => $object->id,
    #         date_occurred => $event->date_occurred
    #     });
    #     if (!defined($db_event)) {
    #         $error = 'Error: bad event ' . $event->object . ' '
    #             . $event->action . ' ' . $event->date_occurred;
    #         last;
    #     }
    #     # add all params
    #     my $params = $event->params;
    #     if (defined($params)) {
    #         foreach my $param_name (keys %{$params}) {
    #             my $event_param = $c->model('OsgoodDB::EventParameter')->create({
    #                 event_id => $db_event->id,
    #                 name => $param_name,
    #                 value => $params->{$param_name}
    #             });
    #             if (!defined($event_param)) {
    #                 $error = 'Error: bad event parameter' .  $param_name .
    #                          ' ' .  $params->{$param_name};
    #             }
    #         }
    #     }
    # 
    #     # increment count of inserted events
    #     $count++;
    # }
    # 
    # if (defined($error)) {      # if error, rollback
    #     $count = 0;             # if error, count is zero. nothing inserted.
    #     $schema->txn_rollback;
    # } else {                    # otherwise, commit
    #     $schema->txn_commit;
    # }

    my ($count, $error) = $c->add_from_list($list);

    $c->stash->{count} = $count;

    $self->status_ok($c,
        entity => {
            error => $error,
            count => $count
        }
    );
}

=head2 end

Attempt to render a view, if needed.

=head1 AUTHOR

Lauren O'Meara

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Magazines.com, LLC

You can redistribute and/or modify this code under the same terms as Perl
itself.

=cut

1;
