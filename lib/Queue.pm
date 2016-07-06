package Queue;

use strict;
use warnings;

use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Config;

use common;
use Data::Dumper;

has [qw( db config messages queue pids done)];

# This method will run once at server start
sub startup {
	my $self = shift;

	$self->types->type(json => 'application/json; charset=utf-8');
	$self->types->type(text => 'text/plain; charset=utf-8');
	$self->types->type(html => 'text/html; charset=utf-8');

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	$config = $self->plugin('Config');

	$self->sessions->default_expiration(86400);

	# Clear log if debus status
	if ($config->{'debug'}) {
		`/dev/null > $config->{'log'}`;
	}

	write_log("=====Start script=====");

	# load queues from storage if first start or restart application
	load_queues();

	# Run queues if exists pids queue
# ???????

	# Session for auth
	my $sessions = Mojolicious::Sessions->new;
	$sessions->cookie_name('session');

#	$self->plugin('database', { 
#		dsn	  		=> $config->{database}->{dsn},
#		username	=> $config->{database}->{username},
#		password	=> $config->{database}->{password},
#		options		=> { RaiseError => 1,  PrintError => 1 , mysql_enable_utf8 => 1 , mysql_auto_reconnect => 1},
#		helper		=> 'db',
#	});

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->any('/')				->to('index#index');

	$r->any('/put')				->to('put#queue_put');
	$r->any('/ask')				->to('ask#queue_ask');
	$r->any('/read')			->to('read#queue_read');

	$r->any('/addjob')			->to('index#job_add');
	$r->any('/status')			->to('index#job_status');
	$r->any('/killer')			->to('index#job_kill');
	$r->any('/done')			->to('index#job_done');

	$r->any('/addpreset')		->to('index#preset_add');
	$r->any('/editpreset')		->to('index#preset_edit');
	$r->any('/savepreset')		->to('index#preset_save');

	$r->any('/alljobs')			->to('index#jobs_all');
	$r->any('/searchjob')		->to('index#job_search');

	$r->any('/testexec')		->to('index#test_exec');
	$r->any('/testresult')		->to('index#test_result');

#	$r->any('/logout')			->to('auth#logout');
#	my $auth = $r->under()		->to('auth#login');

#	$auth->any('/admin')		->to('admin#simple');

	$self->secrets(['*pOpRTm;M<;5?fk{']);

}

1;
