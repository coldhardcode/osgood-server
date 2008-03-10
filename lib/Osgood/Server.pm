package Osgood::Server;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a YAML file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use Catalyst qw/-Debug ConfigLoader Static::Simple/;

our $VERSION = '1.0.5';
our $AUTHORITY = 'cpan:GPHAT';

# Configure the application. 
#
# Note that settings in osgood_server.yml (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config( name => 'Osgood::Server' );

# Start the application
__PACKAGE__->setup;


=head1 NAME

Osgood::Server - Catalyst based application

=head1 SYNOPSIS

    script/osgood_server_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Osgood::Server::Controller::Root>, L<Catalyst>, L<Osgood::Client>

=head1 AUTHOR

Lauren O'Meara

Cory 'G' Watson <gphat@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Magazines.com, LLC

You can redistribute and/or modify this code under the same terms as Perl
itself.

=cut

1;
