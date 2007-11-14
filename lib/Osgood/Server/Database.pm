package Osgood::Server::Database;
use strict;

=head1 NAME

Osgood::Server::Database - Database Methods

=head1 DESCRIPTION

Osgood::Server::Database wraps some of the mundane steps in establishing a database
connection to a database established in the Osgood config file.  When
the constructor is called, a database name should be passed in, which should
correspond to an entry in the config file:

<configuration>
 <database>
  <test>
   <name>test</name>
   <host>127.0.0.1</host>
   <port>3306</port>
   <driver>mysql</driver>
   <username>testuser</username>
   <password>testpass</password>
  </test>
 </database>
</configuration>

Given such a config entry, calling 'new Osgood::Server::Database("test")' would
establish return a suitably configured Osgood::Server::Database upon which connect()
can be called to return a DBI database handle.

This code also allows connections via different drivers.  These can be set
with the driver() accessor.  'Pg' and 'mysql' are supported.

=head1 SYNOPSIS

  my $db = Osgood::Server::Database->new($dbname);
  my $dbh = $db->connect();
  # Do Something with $dbh...
  $dbh->disconnect();

=cut

use DBI;

use Osgood::Config;
use Osgood::Server::Schema;

=head1 METHODS

=head2 Constructor

=over 4

=item Osgood::Server::Database->new()

Creates and returns a new Osgood::Server::Database object.  Defaults to the
database host, port, and password from Osgood::Config for 'moe'.

=back

=cut
sub new {
    my $self = {};
    my $proto = shift();
    my $db = shift() || Osgood::Config->fetch('/database/default');
    unless(defined(Osgood::Config->fetch("database/$db/name"))) {
        die("No such database '$db' in config file!");
    }
    $self->{DRIVER} = Osgood::Config->fetch("database/$db/driver");
    unless($self->{DRIVER}) {
        $self->{DRIVER} = "mysql";
    }

    $self->{DBNAME} = Osgood::Config->fetch("database/$db/name");
    $self->{HOST}   = Osgood::Config->fetch("database/$db/host");
    $self->{PORT}   = Osgood::Config->fetch("database/$db/port");
    $self->{USER}   = Osgood::Config->fetch("database/$db/username");
    $self->{PASS}   = Osgood::Config->fetch("database/$db/password");
    bless($self);
    return $self;
}

=head2 Class Methods

=over 4

=item $db->options

Connection options

=cut
sub options {
    my $self = shift();

    return {
        AutoCommit  => 1,
        RaiseError  => 1,
        mysql_auto_reconnect => 1,
    };
}

=item $db->dsn()

Get this connection's DSN

=cut
sub dsn {
    my $self = shift();

    my $dsn = 'dbi:'.$self->driver().':';
    #if($self->driver() eq "Pg") {
    #    $dsn .= "dbname=";
    #}  else {
        $dsn .= "database=";
    #}
    $dsn .= $self->database();

    if(defined($self->host())) {
        $dsn .= ";host=".$self->host().";port=".$self->port().";";
    }

    return $dsn;
}

=item $db->connect()

Connects to the database and returns a DBI database handle.

=cut
sub connect {
    my $self = shift();

    my $dbh = DBI->connect(
            $self->dsn(), $self->user(), $self->pass(), $self->options()
    );
    return $dbh;
}

=item $db->driver()

=item $db->driver($driver)

Sets/Gets the driver value.  Currently can use MySQL.

=cut
sub driver {
    my $self = shift();
    if(@_) { $self->{DRIVER} = shift() }
    return $self->{DRIVER};
}

=item $db->host()

=item $db->host($host)

Sets/Gets the host value.

=cut
sub host {
    my $self = shift();
    if(@_) { $self->{HOST} = shift() }
    return $self->{HOST};
}

=item $db->port()

=item $db->port($port)

Sets/Gets the port value.

=cut
sub port {
    my $self = shift();
    if(@_) { $self->{PORT} = shift() }
    return $self->{PORT};
}

=item $db->user()

=item $db->user($user)

Sets/Gets the user value.

=cut
sub user {
    my $self = shift();
    if(@_) { $self->{USER} = shift() }
    return $self->{USER};
}

=item $db->pass()

=item $db->pass($pass)

Sets/Gets the pass value.

=cut
sub pass {
    my $self = shift();
    if(@_) { $self->{PASS} = shift() }
    return $self->{PASS};
}

=item $db->database()

=item $db->database($dbname)

Sets/Gets the name of the database to connect to.

=cut
sub database {
    my $self = shift();
    if(@_) { $self->{DBNAME} = shift() }
    return $self->{DBNAME};
}

=item get_schema

connects and returns a schema.  this method can be used as
an object method or as a class method.  if used as a class
method, a new Osgood::Server::Database object is instantiated
before connecting the schema.

=cut

sub get_schema
{
	my $self = shift;

	$self = new Osgood::Server::Database @_ if not ref $self;

	my $args	= { quote_char => '`', name_sep => '.' };
	my $schema	= Osgood::Server::Schema->connect($self->dsn, $self->user, $self->pass, $self->options, $args);

	return $schema;
}

=back

=head2 Static Methods

=over 4

NONE.

=back

=head1 AUTHOR

Cory 'G' Watson <cwatson@magazines.com>

=head1 SEE ALSO

perl(1), DBI

=cut
1;
