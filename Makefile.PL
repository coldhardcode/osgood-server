use inc::Module::Install;

name 'Osgood-Server';
all_from 'lib/Osgood/Server.pm';

requires 'DateTime';
requires 'DateTime::Format::MySQL';
requires 'Osgood::Client';

requires 'Catalyst::Runtime' => '5.7011';
requires 'Catalyst::Model::DBIC::Schema';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Params::Nested';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::REST::XML' => 0;
requires 'YAML'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
