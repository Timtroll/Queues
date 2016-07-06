package Queue::Controller::Index;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use common;

use Data::Dumper;

sub index {
	my ($self, $preset, $msg, $load, %data);
	$self = shift;

	write_log("\n\n\n=====index=====");

	# get list of preset jobs
	($preset, $msg) = list_of_preset();
	unless ($msg) { $msg = ' '; }

	$load = load_balancer();

	%data = (
		preset	=> $preset,
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> 'Main page',
		load	=> $load,
		config	=> $config,
		msg		=> $msg
	);
	$self->render('index/index', %data);
}

sub jobs_all {
	my ($self, $jobs, $msg, %data);
	$self = shift;

	write_log("\n\n\n=====jobs_all=====");

	($jobs, $msg) = list_jobs();

	# Render list of jobs template "index/test.html.ep"
	%data = (
		title	=> 'All jobs',
		jobs	=> $jobs,
		msg		=> $msg
	);
	$self->render('index/alljobs', %data);
}

sub job_search {
	my ($self, $pid, $line, $status, $msg, %data);
	$self = shift;

	write_log("\n\n\n=====job_search=====");

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

sub job_add {
	my ($self, $line, $job, $tmp, $pid, $msg, $mess, $preset, $error, $load, %data, %in);
	$self = shift;

	write_log("\n\n\n=====job_add=====");

	# Add tasks to your application
	%in = (
		'action'			=> 'put',
		'output'			=> $config->{'exec_apps'}->{'output_dir'},
		'quality'			=> 100,
		'resolution'		=> 72,
		'password'			=> 'textpass',
		'size'	=>	{
			'width'		=> 2000,
			'height'	=> 2000
		}
	);
	if ($self->param('conversion_type')) {
		# set soure/output dir variable
		$in{'conversion_type'} = $tmp = $self->param('conversion_type');
		if (-e "$config->{'templates_dir'}/$in{'conversion_type'}.txt.ep") {
			$tmp =~ s/\d.*$//;
			$in{'source'} = "$config->{'exec_apps'}->{'source_dir'}/$in{'conversion_type'}.$tmp";
		}
	}
	if ($in{'conversion_type'}) {
		($pid, $error) = $self->create_job($in{'conversion_type'}, \%in);

		$msg = ' ';
		if ($pid) {
			$msg = $config->{'messages'}->{'ran_success'} . $pid;
		}
		else {
			$msg = $error;
		}
	}
	else {
		$msg = $config->{'messages'}->{'empty_job'};
	}

	# get list of preset jobs
	($preset, $mess) = list_of_preset();
	if ($mess) { $msg .= "<br>$mess"; }

	$load = load_balancer();

	# Render list of jobs template "index/test.html.ep"
	%data = (
		preset	=> $preset,
		queue	=> \%queue,
		pids	=> \%pids,
		done	=> \%done,
		title	=> 'Queues page',
		load	=> $load,
		config	=> $config,
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

	write_log("\n\n\n=====job_done=$pid=====");

	# get all messages & remove process 
	$pid = $self->param('pid');

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

sub preset_save {
	my ($self, $id, $preset, $msg, $status, $load, %data);
	$self = shift;

	# get preset id and preset valeu for save
	$id = $self->param('id');
	$preset = $self->param('preset');

	if ($id) {
		$msg = $config->{'messages'}->{'preset_saved'}.$id;
		($preset, $status) = save_preset($id, $preset);
		unless ($status) {
			$msg = $config->{'messages'}->{'can_not_rw_preset'}.$config->{'templates_dir'};
		}
		elsif ($status == 2) {
			$msg = $config->{'messages'}->{'not_exists_dir'}.$id;
		}

		%data = (
			preset	=> $preset,
			id		=> $id,
			title	=> 'Edit preset job page',
			config	=> $config,
			msg		=> $msg
		);
		$self->render('index/editpreset', %data);
	}
	else {
		$msg = $config->{'messages'}->{'empty_preset'};

		# get list of preset jobs
		($preset, $msg) = list_of_preset();
		unless ($msg) { $msg = ' '; }

		$load = load_balancer();

		%data = (
			preset	=> $preset,
			queue	=> \%queue,
			pids	=> \%pids,
			done	=> \%done,
			title	=> 'Main page',
			load	=> $load,
			config	=> $config,
			msg		=> $msg
		);
		$self->render('index/index', %data);
	}
}

sub preset_edit {
	my ($self, $id, $preset, $msg, $status, %data);
	$self = shift;

	# get preset id
	$id = $self->param('id');

	write_log("\n\n\n=====preset_edit=$id=====");

	if ($id) {
		($preset, $status) = edit_preset($id);
		unless ($status) {
			$msg = $config->{'messages'}->{'not_exists_preset'}.$id;
		}
		elsif ($status == 2) {
			$msg = $config->{'messages'}->{'can_not_rw_preset'}.$id;
		}
	}
	else {
		$msg = $config->{'messages'}->{'empty_preset'};
	}

	%data = (
		preset	=> $preset,
		id		=> $id,
		title	=> 'Edit preset job page',
		config	=> $config,
		msg		=> $msg
	);
	$self->render('index/editpreset', %data);
}

1;
