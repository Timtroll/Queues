package Queue::Controller::Index;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use common;

use Data::Dumper;

sub index {
	my ($self, $preset, $msg, %data);
	$self = shift;

	# get list of preset jobs
	($preset, $msg) = list_of_preset();
	unless ($msg) { $msg = ' '; }

	%data = (
		preset	=> $preset,
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> 'Main page',
		msg		=> $msg
	);
	$self->render('index/index', %data);
}

sub job_add {
	my ($self, $line, $job_num, $pid, $msg, $mess, $preset, $error, %data, %in);
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
		$msg = $config->{'messages'}->{'ran_success'} . $pid;
	}
	else {
		$msg = $error;
	}

	# get list of preset jobs
	($preset, $mess) = list_of_preset();
	if ($mess) { $msg .= "<br>$mess"; }

	# Render list of jobs template "index/test.html.ep"
	%data = (
		preset	=> $preset,
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
	my ($self, $pid, $mess, $msg, $preset, %data);
	$self = shift;

write_log("\n\n\n=====job_kill=====");

	# kill exists process
	$pid = $self->param('pid');
	if ($pid) {
		if (ref($pids{$pid}) eq 'HASH') {
			# kill process
			kill_job($pid);
		}
	}

	# get list of preset jobs
	$mess = "<br> Killed job pid = $pid";
	($preset, $msg) = list_of_preset();
	if ($msg) { $msg .= $mess; }

	%data = (
		preset	=> $preset,
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> "Killed job",
		msg		=> $mess
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
		if (ref($pids{$pid}) eq 'HASH') {
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
