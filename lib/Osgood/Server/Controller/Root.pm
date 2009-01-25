package Osgood::Server::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller::REST';

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

=head2 event_POST

=cut
sub event_POST {
    my ($self, $c) = @_;

	# wrap the insert in a transaction. if any one fails, they all do
	my $schema = $c->model('OsgoodDB')->schema;
	$schema->txn_begin;

    my $events = $c->req->data;

    my $list = Osgood::EventList->unpack($events);
    my $iter = $list->iterator;
    # count events
    my $count = 0;
    my $error = undef;

    while (($iter->has_next) && (!defined($error))) {
        my $event = $iter->next;

        # find or create the action
        my $action = $c->model('OsgoodDB::Action')->find_or_create({
            name => $event->action
        });
        if (!defined($action)) {
            $error = "Error: bad action " . $event->action();
            last;
        }
        # find or create the object
        my $object = $c->model('OsgoodDB::Object')->find_or_create({
            name => $event->object
        });
        if (!defined($object)) {
            $error = "Error: bad object " . $event->object;
            last;
        }
        # create event - this has to be a new thing. no find here. 
        my $db_event = $c->model('OsgoodDB::Event')->create({
            action_id => $action->id,
            object_id => $object->id,
            date_occurred => $event->date_occurred
        });
        if (!defined($db_event)) {
            $error = 'Error: bad event ' . $event->object . ' ' .
            $event->action . ' ' . $event->date_occurred;
            last;
        }
        # add all params
        my $params = $event->params;
        if (defined($params)) {
            foreach my $param_name (keys %{$params}) {
                my $event_param = $c->model('OsgoodDB::EventParameter')->create({
                    event_id => $db_event->id,
                    name => $param_name,
                    value => $params->{$param_name}
                });
                if (!defined($event_param)) {
                    $error = 'Error: bad event parameter' .  $param_name .
                             ' ' .  $params->{$param_name};
                }
            }
        }

        # increment count of inserted events
        $count++;
    }

    if (defined($error)) {         # if error, rollback
        $count = 0; # if error, count is zero. nothing inserted.
        $schema->txn_rollback;
        # $c->stash->{error} = $error;
    } else {                        # otherwise, commit
        $schema->txn_commit;
    }

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

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Lauren O'Meara

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Magazines.com, LLC

You can redistribute and/or modify this code under the same terms as Perl
itself.

=cut

1;
