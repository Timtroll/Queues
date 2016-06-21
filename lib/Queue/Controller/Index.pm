package Queue::Controller::Index;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use common;

use Data::Dumper;

sub index {
	my ($self, %data);
	$self = shift;

	%data = (
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> 'Main page',
		msg		=> ' '
	);
	$self->render('index/index', %data);
}

sub job_add {
	my ($self, $line, $job_num, $pid, $msg, $error, %data, %in);
	$self = shift;

write_log("\n\n\n=====job_add=====");
	# Add tasks to your application
	%in = (
		'action'			=> 'put',
		'conversion_type'	=> $self->param('conversion_type'),
		'source'			=> '',
		'output'			=> '',
		'quality'			=> 100,
		'resolution'		=> 72,
		'password'			=> 'textpass',
		'size'	=>	{
			'width'		=> 2000,
			'height'	=> 2000
		}
	);
	($pid, $error) = $self->create_job($in{'conversion_type'}, \%in);

	$msg = ' ';
	if ($pid) {
		$msg = $config->{'nessages'}->{'ran_success'} . $pid;
	}
	else {
		$msg = $error;
	}

	# Render list of jobs template "index/test.html.ep"
	%data = (
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> 'Queues page',
		msg		=> $msg
	);
	$self->render('index/index', %data);
}

sub job_status {
	my ($self, $pid, $line, $status, $msg, %data);
	$self = shift;

write_log("\n\n\n=====job_status=====");

	# Get info from running tasks
	$pid = $self->param('pid');
	($line, $status) = info_job($pid);
	$msg = ' ';
	if (!$status && !$line) {
		$msg = $config->{'messages'}->{'not_exists_job'};
	}
	elsif (!$status && $line) {
		$msg = $line;
	}

	# Render template "index/status.html.ep" with message
	%data = ( 
		title	=> "Information about pid=$pid",
		pid		=> $pid,
		line	=> $line,
		msg		=> $msg
	);
	$self->render('index/status', %data);
}

sub job_kill {
	my ($self, $pid, %data);
	$self = shift;

write_log("\n\n\n=====job_kill=====");

	# kill exists process
	$pid = $self->param('pid');
	if ($pid) {
		if (exists $pids{$pid}) {
			# kill process
			kill_job($pid);
		}
	}

	%data = (
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> "Killed job",
		msg		=> "Killed job pid = $pid"
	);
	$self->render('index/index', %data);
}

sub job_done {
	my ($self, $pid, $status, $out);
	$self = shift;

	# get all messages & remove process 
	$pid = $self->param('pid');
write_log("\n\n\n=====job_done=====-$pid-=");

	if ($pid) {
		if (exists $pids{$pid}) {
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

	unless ($out->{'msg'}) { $out->{'msg'} = ' '; }

	$self->render(json => $out );
}

1;
