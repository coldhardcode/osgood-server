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

our $VERSION = '1.1.0';
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

Osgood::Server - Event Repository

=head1 SYNOPSIS

    create a database (mysql in our example)
    mysql -u root your_database < sql/schema.sql
    script/osgood_server_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 PERFORMANCE

Note: See the accompanying section of Osgood::Client as well.

Osgood uses some DBIx::Class shortcuts to pull results faster.  Depending on
database hardware, small numbers of events (hundreds) should be really fast.
Tests have been conducted on lists of 10_000 events and the response time still
falls within ::Client's default 30 second timeout on modern hardware.

=head1 SEE ALSO

L<Osgood::Server::Controller::Root>, L<Catalyst>, L<Osgood::Client>

=head1 AUTHORS

Lauren O'Meara

Cory 'G' Watson <gphat@cpan.org>

=head1 CONTRIBUTORS

Guillermo Roditi (groditi)

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Magazines.com, LLC

You can redistribute and/or modify this code under the same terms as Perl
itself.

=cut

1;
