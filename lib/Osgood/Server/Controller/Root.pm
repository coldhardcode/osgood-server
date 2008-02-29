package Osgood::Server::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

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
