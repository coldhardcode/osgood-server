package Osgood::Server::Schema;
use strict;

use Osgood::Server::Database;

# import YAML Loader/Dumper subclasses for inflate/deflate
use Greenspan::Util::YAML::Loader;
use Greenspan::Util::YAML::Dumper;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_classes({
	'Osgood::Server::Model' => [
	qw/
		Action
		Event
		EventParameter
		Object
	/]
});

sub connect
{
	my $self = shift;

	my $schema = $self->next::method(@_);

	$schema->storage->dbh->do('SET @@SQL_AUTO_IS_NULL=0') if $schema;

	return $schema;
}

sub inflate
{
	my $self = shift;
	my $yaml = new Greenspan::Util::YAML::Loader $self;

	return $yaml->load(@_);
}

sub deflate
{
	my $self = shift;
	my $yaml = new Greenspan::Util::YAML::Dumper;

	return $yaml->dump(@_);
}

1;
