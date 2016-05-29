package Queue::Controller::Index;

use Mojo::Base 'Mojolicious::Controller';

use Socket;
use IO::Select;
use IO::Handle;

use common;

use Data::Dumper;

sub index {
	my ($self, $jobs, $line, %data);
	$self = shift;

	# check exists pids
	foreach (%{$pids}) {
		# Get info from running tasks
		if ($_) {
			info_job($_);
		}
	}

	%data = (
		jobs	=> $pids,
		pid		=> '',
		msg		=> ''
	);
	$self->render('index/index', %data);
}

sub addjob {
	my ($self, $line, $job_num, $pid, $url, $msg, %data);
	$self = shift;

	# Add tasks to your application
	$url = $self->param('url');

	($pids, $pid) = create_job("ping $url");
	if ($pid) {
		$msg = "You ran process pid=$pid";
	}

	# Render list of jobs template "index/test.html.ep"
	%data = (
		jobs	=> $pids,
		pid		=> $pid,
		msg		=> $msg
	);
	$self->render('index/test', %data);
}

sub status {
	my ($self, $jobs, $line, %data);
	$self = shift;

	# Get info from running tasks
	($jobs, $line) = info_job($self->param('pid'));

	# Render template "index/status.html.ep" with message
	%data = (
		jobs	=> $jobs, 
		line	=> $line
	);
	$self->render('index/status', %data);
}

sub killer {
	my ($self, $pid, %data);
	$self = shift;

	# kill exists process
	$pid = $self->param('pid');
	if ($pid) {
		if ($pids->{$pid}) {
			# kill process
			kill_process($pid);
		}
	}

	%data = (
		jobs	=> $pids,
		pid		=> '',
		msg		=> ''
	);
	$self->render('index/index', %data);
}

1;
