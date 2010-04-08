package Osgood::Server::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller::REST';

use DBIx::Class::ResultClass::HashRefInflator;
use DateTime::Format::DBI;
use JSON::XS qw(encode_json);

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

    if($c->req->params->{limit}) {
        $events = $events->search(undef, { page => 1, rows => $c->req->params->{limit} });
    }

    $events->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $dt_parser = DateTime::Format::DBI->new(
        $c->model('OsgoodDB')->schema->storage->dbh
    );

    my $limit = $c->req->params->{'limit'};
    my @event_list;
    if (defined($events)) {
        while (my $event = $events->next) {
            # convert db event to net event
            my $params = {};
            if(scalar($event->{'parameters'})) {
                foreach (@{ $event->{'parameters'} }) {
                    $params->{$_->{'name'}} = $_->{'value'};
                }
            }

            push(@event_list, {
                id => $event->{event_id},
                object  => $event->{object}->{name},
                action  => $event->{action}->{name},
                date_occurred => $event->{date_occurred},
                params => $params
            });
        }
    }

    # set response type
    $c->response->content_type('application/json');
    # return serialized list
    $c->response->body(encode_json(\@event_list));
}

=head2 event_POST

=cut
sub event_POST {
    my ($self, $c) = @_;

    my $events = $c->req->data;

    my $list = Osgood::EventList->new(
        list => $c->req->data
    );

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
