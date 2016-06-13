package Queue::Controller::Index;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use common;

use Data::Dumper;

sub index {
	my ($self, %data);
	$self = shift;

print Dumper($queue_l);
print Dumper($pids_l);
print Dumper($done_l);

	%data = (
		queue	=> $queue_l,
		pids	=> $pids_l,
		done	=> $done_l,,
		title	=> 'Main page',
		msg		=> ' '
	);
	$self->render('index/index', %data);
}

sub job_add {
	my ($self, $line, $job_num, $pid, $msg, $error, %data, %in);
	$self = shift;

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
		queue	=> $queue_l,
		pids	=> $pids_l,
		done	=> $done_l,
		title	=> 'Queues page',
		msg		=> $msg
	);
	$self->render('index/index', %data);
}

sub job_status {
	my ($self, $pid, $line, $status, $msg, %data);
	$self = shift;

print Dumper($queue_l);
print Dumper($pids_l);
print Dumper($done_l);

	# Get info from running tasks
	$pid = $self->param('pid');
	($line, $status) = info_job($pid);
	$msg = ' ';
	unless ($status) {
		$msg = $config->{'messages'}->{'not_exists_job'};
	}

	# Render template "index/status.html.ep" with message
	%data = (
		queue	=> $queue_l, 
		pids	=> $pids_l, 
		done	=> $done_l,
 
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

print Dumper($queue_l);
print Dumper($pids_l);
print Dumper($done_l);

	# kill exists process
	$pid = $self->param('pid');
	if ($pid) {
		if (exists $$pids_l{$pid}) {
			# kill process
			kill_job($pid);
		}
	}

	%data = (
		queue	=> $queue_l,
		pids	=> $pids_l,
		done	=> $done_l,
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
print ">>>>> $pid  <<<<<<<\nqueue = $$queue_l{$pid}\npids = $$pids_l{$pid}\ndone = $$done_l{$pid}\n";
print Dumper($queue_l);
print Dumper($pids_l);
print Dumper($done_l);


	if ($pid) {
		if ($$pids_l{$pid}) {
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
