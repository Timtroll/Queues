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

sub job_add {
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

sub job_status {
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

sub job_kill {
	my ($self, $pid, $jobs, %data);
	$self = shift;

	# kill exists process
	$pid = $self->param('pid');
	if ($pid) {
		if ($$pids{$pid}) {
			# kill process
			kill_job($pid);
		}
	}

	%data = (
		jobs	=> $pids,
		pid		=> '',
		msg		=> ''
	);
	$self->render('index/index', %data);
}

sub job_done {
	my ($self, $pid, $status, $out);
	$self = shift;

	# get all messages & remove process 
	$pid = $self->param('pid');
print ">>>>> $pid $$pids{$pid} <<<<<<<";
	if ($pid) {
		if ($$pids{$pid}) {
			# get all messages & remove process 
			$status = done_job($pid);

			$out = {
				queue_id=> $pid,
				msg		=> $config->{'messages'}->{'done_job'} . $pid
			};
			if ($status) {
				$out->{'status'} = 200;
			}
			else {
				$out = {
					status	=> 503,
					msg		=> $config->{'messages'}->{'deleting_error'} . $pid
				};
			}
		}
		else {
			$out = {
				status	=> 404,
				queue_id=> $pid,
				msg		=> $config->{'messages'}->{'not_exists_job'} . $pid
			};
		}
	}
	else {
		$out = {
			status	=> 400,
			msg		=> $config->{'messages'}->{'not_exists_job_id'}
		};
	}

	$self->render(json => $out );
}

1;
