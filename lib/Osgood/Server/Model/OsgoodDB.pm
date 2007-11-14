package Osgood::Server::Model::OsgoodDB;
use strict;

use Osgood::Server::Database;

use base qw(Catalyst::Model::DBIC::Schema);

my $db = new Osgood::Server::Database;

__PACKAGE__->config(
	schema_class => 'Osgood::Server::Schema',
	connect_info => [
		$db->dsn(),
		$db->user(),
		$db->pass(),
		$db->options(),
		{
			'quote_char' => '`',
			'name_sep' => '.'
		}
	]
)
