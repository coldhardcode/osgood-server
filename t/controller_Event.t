use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Osgood::Server' }
BEGIN { use_ok 'Osgood::Server::Controller::Event' }

ok( request('/event')->is_success, 'Request should succeed' );

ok( request('/event/list?id_greater=1')->is_success, 'list');

