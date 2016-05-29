package Queue;

use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Config;

use IO::Handle;

use common;

has [qw( db config messages selread pids)];

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

	# Session for auth
	my $sessions = Mojolicious::Sessions->new;
	$sessions->cookie_name('session');

	$self->plugin('database', { 
		dsn	  		=> $config->{database}->{dsn},
		username	=> $config->{database}->{username},
		password	=> $config->{database}->{password},
		options		=> { RaiseError => 1,  PrintError => 1 , mysql_enable_utf8 => 1 , mysql_auto_reconnect => 1},
		helper		=> 'db',
	});

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->any('/')				->to('index#index');

	$r->any('/put')				->to('put#queue_put');
	$r->any('/ask')				->to('ask#queue_ask');
	$r->any('/read')			->to('read#queue_read');

	$r->any('/addjob')			->to('index#addjob');
	$r->any('/status')			->to('index#status');
	$r->any('/killer')			->to('index#killer');

#	$r->any('/logout')			->to('auth#logout');
#	my $auth = $r->under()		->to('auth#login');

#	$auth->any('/admin')		->to('admin#simple');

	$self->secrets(['*pOpRTm;M<;5?fk{']);

}

1;
