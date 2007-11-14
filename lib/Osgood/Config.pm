package Osgood::Config;
use strict;

=head1 NAME

Osgood::Config - Configuration

=head1 DESCRIPTION

Osgood::Config parses the file /etc/greenspan/osgood.xml using XML::XPath
when it is loaded (therefore being 'free' anytime it is used again by the
interpreter) and exposes a fetch("some/value") method for retrieving values
from the config file.  For example, if the config file looks like:

<?xml version="1.0" encoding="UTF-8"?>
<configuration>
 <some>
  <value>hello!</value>
 </some>
</configuration>

then fetch("some/value") will return "hello!".  The root element configuration
is assumed, and is automatically prepended to the path provided.

After a key is used, it's return value (if defined) is cached.  The same rules
applied to getNodes().  Subsequent lookups will simply be given the result
from the cache.  This significantly speeds up Osgood::Config's use.

=head1 SYNOPSIS

  use Osgood::Config;

  my $val = Osgood::Config->fetch("key");

=cut

use XML::XPath;
use XML::XPath::Node;

my $xp;
my %cache;

BEGIN {
    unless(-e "/etc/greenspan/osgood.xml") {
        die("/etc/greenspan/osgood.xml not found!!");
    }
    $xp = XML::XPath->new(filename => "/etc/greenspan/osgood.xml");
}

=head1 METHODS

=over 4

=item fetch($key)

Fetch the value of the specified key.  Returns undef is key does not exist.

=cut
sub fetch {
    my $self = shift();
    my $key = shift();

    if(exists($cache{$key})) {
		# exists, but is undef
		if (not defined $cache{$key}) {
			return wantarray ? () : undef;
		}

		return wantarray ? @{ $cache{$key} } : join ',', @{ $cache{$key} };
    }

    my $newkey = "/configuration/$key";

	# XML::XPath says:
	#
	#   getNodeText($path)
	#   Returns the text string for a particular XML node.  Returns
	#   a string, or undef if the node doesn't exist.
	#
	# however, this is not the case.  it does NOT return undef
	# if the node doesn't exist.  so, we have to explicitly check
	# for the node by using the exists() method

	if (not $xp->exists($newkey)) {
		$cache{$key} = undef;
		return wantarray ? () : undef;
	}

	# use XML::XPath->findnodes to get all nodes
	$cache{$key} = [ map { $_->string_value } $xp->findnodes($newkey) ];

	# return as an array or as a comma-separated string, however you want it
	return wantarray ? @{ $cache{$key} } : join ',', @{ $cache{$key} };
}

=item override

overrides the specified configuration pair.  useful for tests.

=cut

sub override
{
	my $self	= shift;
	my $key		= shift;

	$cache{$key} = [ @_ ];
}

=item get_nodes($expr)

Fetch all the nodes for the given XPath expression

=cut
sub get_nodes {
    my $self = shift();
    my $expr = shift();

    my $newexp = "/configuration/";
    $newexp .= $expr;
    if(exists($cache{$newexp})) {
        return $cache{$newexp};
    }

    my $val = $xp->find($newexp);
    if(defined($val)) {
        $cache{$newexp} = $val;
    }
    return $val;
}

=item get_pairs

fetch all of the node/text pairs as a hashref for the
given xpath expression

=cut

sub get_pairs {
    my $self = shift();

    my $set = $self->get_nodes(shift() . '/*');
    my $href = {};

    for (my $i = 1; $i <= $set->size; $i++) {
        my $node = $set->get_node($i);

        next if $node->getNodeType != ELEMENT_NODE;

        $href->{ $node->getName } = $node->string_value;
    }

    return $href;
}

=back

=head1 AUTHOR

Cory Watson <cwatson@magazines.com>

=head1 SEE ALSO

perl(1), <XML::XPath>

=cut
1;
