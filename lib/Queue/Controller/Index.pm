package Queue::Controller::Index;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use common;

use Data::Dumper;

sub index {
	my ($self, $jobs, %data);
	$self = shift;

	%data = (
		jobs	=> $pids,
		pid		=> '',
		msg		=> ''
	);
	$self->render('index/index', %data);
}

sub addjob {
	my ($self, $line, $job_num, $jobs, $pid, $url, $msg, %data);
	$self = shift;

	# Add tasks to your application
	$url = $self->param('url');

	$pid = create_job("ping $url");
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
	$line = info_job($self->param('pid'));

	# Render template "index/status.html.ep" with message
	%data = (
		jobs	=> $pids, 
		line	=> $line
	);
	$self->render('index/status', %data);
}

sub killer {
	my ($self, $pid, $jobs, %data);
	$self = shift;

	# kill exists process
	$pid = $self->param('pid');
	if ($pid) {
		if ($$pids{$pid}) {
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
