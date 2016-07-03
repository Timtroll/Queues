package common;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use JSON::XS;
use Time::HiRes qw(gettimeofday);
use Data::Dumper;

use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK $config $messages %queue %pids %done );

use utf8;
$| = 1;

use libbash;

our @ISA = qw( Exporter );
our @EXPORT = qw(
	$config $messages %queue %pids %done 
	&done_job &info_job &create_job &kill_job &get_pdf_res &load_queues &store_queues &list_of_preset
	&write_log
);

our ($config, $messages, %queue, %pids, %done);
%queue = ();
%pids = ();
%done = ();

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0
		#'SSL_VERIFY_NONE'
	);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

############ queues ############

sub store_queues {
	my ($type, $status);
	($type) = @_;

	write_log("Store queues lock=$config->{'lock'}");

	if (scalar(keys %queue)) {
		$status = store_queue('queue');
		unless ($status) { return 'queue'; }
	}
	else { unlink ("$config->{'storage_dir'}/queue"); }

	if (scalar(keys %pids)) {
		$status = store_queue('pids');
		unless ($status) { return 'pids'; }
	}
	else { unlink ("$config->{'storage_dir'}/pids"); }

	if (scalar(keys %done)) {
		$status = store_queue('done');
		unless ($status) { return 'done'; }
	}
	else { unlink ("$config->{'storage_dir'}/done"); }

	write_log("End store queues");
	return 0;
}

sub store_queue {
	my ($type, $link, $line, $cnt, $json_xs, $status);
	$type = shift;

	write_log("Store queue $type");

	$status = 1;

	# check folder for queues
	unless (-d $config->{storage_dir}) {
		write_log("End store queue '$type'. $config->{'messages'}->{'not_exists_queues_dir'}");

		return 0;
	}
	else {
		# create link to queue which are store (queue pids done)
		if ($type eq 'queue') { $link = \%queue; }
		elsif ($type eq 'pids') { $link = \%pids; }
		elsif ($type eq 'done') { $link = \%done; }
		else { return 3; }

		$cnt = scalar(keys %{$link});
		if (($status == 1) && ($cnt)) {
			$json_xs = JSON::XS->new();
			$json_xs->utf8(1);

			$line = '';
			open (FILE, ">$config->{'storage_dir'}/$type") or $status = 0;
				map {
					$line = $json_xs->encode($$link{$_});
					if ($line) {
						if ($cnt > 1) { $line .= "\n"; }
						print FILE $line;
						$line = '';
					}
					$cnt--;
				} (keys %{$link});
			close (FILE) or $status = 0;
		}
	}

	write_log("End store queue $type");

	return $status;
}

sub load_queues {
	my ($status, $messages, @message);

	write_log("Load queues");

	# wait while qeues are storing or moving & then create lock
	while ($config->{'lock'}) {}
	$config->{'lock'} = 'l';

	$status = load_queue('queue');
	unless ($status) { push @message, $config-{'messages'}->{'can_not_open_queue'}."'queue'"; }

	$status = load_queue('pids');
	unless ($status) { push @message, $config-{'messages'}->{'can_not_open_queue'}."'pids'"; }

	$status = load_queue('done');
	unless ($status) { push @message, $config-{'messages'}->{'can_not_open_queue'}."'done'"; }

	# create error messages
	$messages = '';
	if (scalar(@message)) {
		$messages = join("\n", @message);
	}

	# unlock queues
	$config->{'lock'} = 0;

	write_log("End load queues: $messages");

	return $status, $messages;
}

sub load_queue {
	my ($type, $link, $line, $json_xs, $val, $pid, $status);
	$type = shift;

	write_log("Load queue $type");

	# when read all jobs from storage will be replaced exists keys and values
	$status = 1;
	if (-s "$config->{'storage_dir'}/$type") {
		$json_xs = JSON::XS->new();
		$json_xs->utf8(1);

		open (FILE, "<$config->{'storage_dir'}/$type") or $status = 0;
			 while ($line = <FILE>) {
				if ($line) {
					$line =~ s/(\n|\r)//goi;
					$val = $json_xs->decode($line);

					# check key and value
					if ($val->{'md5'}) {
						if ($type eq 'queue') { $queue{$val->{'md5'}} = { %{$val} }; }
						elsif ($type eq 'pids') { $pids{$val->{'md5'}} = { %{$val} }; }
						elsif ($type eq 'done') { $done{$val->{'md5'}} = { %{$val} }; }
					}
					$val = '';
				}
			};
		close (FILE) or $status = 0;
	}
	else {
		unlink "$config->{'storage_dir'}/$type";
	}

	write_log("End load queue $type");

	return $status;
}

sub move_job {
	my ($from_type, $to_type, $pid, $status, $killed);
	($from_type, $to_type, $pid, $killed) = @_;

	write_log("Move job pid='$pid' '$from_type' to '$to_type'");

	# wait while qeues are loading or storing & then create lock
	while ($config->{'lock'}) {}
	$config->{'lock'} = 'm';

	# add/delete queues
	if ($from_type eq 'delete') {
# ??????????
	}
	elsif ($from_type eq 'new') {
		if (ref($pid) ne 'HASH') {
			# unlock queues
			$config->{'lock'} = 0;

			write_log("End move new job '$from_type' to '$to_type' pid=$pid is not a HASH");
			return 0;
		}
		else {
			unless ($$pid{'md5'}) {
				# unlock queues
				$config->{'lock'} = 0;

				write_log("End move new job '$from_type' to '$to_type' md5 is not exists");
				return 0;
			}
		}

		if ($to_type eq 'queue') {
			$queue{$$pid{'md5'}} = $pid;
		}
		elsif ($to_type eq 'pids') {
			$pids{$$pid{'md5'}} = $pid;

			# run moved job
			run_job($pids{$$pid{'md5'}}->{'log'});
		}
		else {
			# unlock queues
			$config->{'lock'} = 0;

			write_log("End move new job '$from_type' to '$to_type' unknown to_queue");
			return 0;
		}
	}
	# moving queues
	elsif ($from_type eq 'queue') {
		if (ref($queue{$pid}) eq 'HASH') {
			$pids{$pid} = $queue{$pid};
			delete $queue{$pid};

			# run moved job
			run_job($pids{$pid}->{'log'});
		}
		else {
			# unlock queues
			$config->{'lock'} = 0;

			write_log("End move job pid=$pid '$from_type' to '$to_type'");
			return 0;
		}
	}
	elsif ($from_type eq 'pids') {
		if (ref($pids{$pid}) eq 'HASH') {
			# delete olderst element from done queue if exceed done-limit
			if (scalar(keys %done) > $config->{'limit_show_done'}) {
				foreach (sort {$done{$a}->{'time'} <=> $done{$b}->{'time'}} keys %done) {
					delete $done{$_};
					last;
				}
			}

			$done{$pid} = $pids{$pid};

			# set status 'killed' if job was kill
			if ($killed) {
				$done{$pid}->{'killed'} = 1;
			}
			delete $pids{$pid};
		}
		else {
			# unlock queues
			$config->{'lock'} = 0;

			write_log("End move job pid=$pid '$from_type' to '$to_type'");
			return 0;
		}
	}
	elsif ($from_type eq 'done') {
		if (ref($done{$pid}) eq 'HASH') {
			# set status 'killed' if job was kill
			if ($killed) {		
				$done{$pid}->{'killed'} = 1;
			}
		}
		else {
			# unlock queues
			$config->{'lock'} = 0;

			write_log("End move job pid=$pid '$from_type' to '$to_type'");
			return 0;
		}
	}
	else {
		# unlock queues
		$config->{'lock'} = 0;

		write_log("End move job '$from_type' to '$to_type'");
		return 0;
	}

	# store queues
	$status = store_queues();
	unless ($status =~ /\d/) {
		# unlock queues
		$config->{'lock'} = 0;

		write_log("Can not store queues. status = '$status', Error store_queues");
		return 0;
	}

	# unlock queues
	$config->{'lock'} = 0;

	write_log("End move job '$from_type' to '$to_type'");
	return 1;
}

sub done_job {
	my ($line, $pid, $count, $dir, $status);
	$pid = shift;

	unless ($pid) {
		write_log("Done job pid not set");
		return 0;
	}
	write_log("Done job pid=$pid");

	# Check exists job & output data from them
	if (ref($pids{$pid}) eq 'HASH') {
		# move pid to done hash
		$status = move_job('pids', 'done', $pid);
		unless ($status) { return 0; }

		# check limit for running jobs and run prepared jobs
		$count = $config->{'limit'} - scalar(keys %pids);
		if ($count) {
			foreach (sort {$queue{$b}->{'time'} <=> $queue{$a}->{'time'}} keys %queue) {
				# run prepared job if exists place in pids queue
				if ($count > 0) {
					$dir = $queue{$_}->{'log'};
					$dir =~ s/\..*?$//;

					# move pid to done hash
					$status = move_job('queue', 'pids', $_);
					$dir = '';
				}
				$count--;
			}
		}

		write_log("End done job pid=$pid");
		return 1;
	}
	else {
		write_log("End done job pid=$pid");
		return 0;
	}
}

sub info_job {
	my ($line, $pid, $link, $status, $mess);
	$pid = shift;

	write_log("Info job $pid");

	$line = '';
	if (-e "$config->{'output_dir'}/$pid/$pid.log") {
		$line = `cat $config->{'output_dir'}/$pid/$pid.log`;

		write_log("End info job $pid");

		return $line, 1;
	}
	else {
		write_log("End info job $pid");

		return '', 0;
	}
}

sub create_job {
	my ($self, $cmd, $tmp, $job, $status, $error, $in, $tm, $dir, %new_pid);
	($self, $job, $in) = @_;

	write_log("Create job $job");

	# set soure/output dir variable
	unless ($$in{'source'}) { $$in{'source'} = $config->{'source_dir'}; }
	unless ($$in{'output'}) { $$in{'output'} = $config->{'output_dir'}; }

	# set up md5 hash for indentify current job
	$$in{'md5'} = create_md5($in);
	unless ($$in{'md5'}) { return 0, ''; }

	# init new pid for adding
	%new_pid =();

	# check exists job and return if exists
	($status, $error) = check_job($$in{'md5'});
	if ($status) { return 0, $error; }

	# check template for job & create exec from template if exists
	if (-e "$config->{'templates_dir'}/$job.txt.ep") {
		$cmd = $self->render_to_string(	
			"$config->{'templates_jobs'}/$job",
			format		=> 'txt',
			in			=> $in,
			icm_profile	=> $config->{'icm_profile'},
			icc_profile	=> $config->{'icc_profile'},
			tmp_dir		=> $config->{'tmp_dir'},
			config		=> $config,
			%{$config->{'exec_apps'}}
		);
	}
	else {
		$cmd = $job;
	}

	# check job add add callback request if exists
	unless ($cmd) { return 0, $error; }
	$cmd .= ";\ncurl $config->{'url'}/done?pid=$$in{'md5'};\n";

	# delete empty lines
	$cmd =~ s/\;(\n|\r)+\;/\;\n/goi;

	# prepare dir for job
	$dir = "$$in{'output'}/$$in{'md5'}";

	# prepare directory for new job
	makedir($dir);

	if (-d "$dir") {
		# prepare command to run and write output into file in background 
		echo_command($cmd, "$dir/$$in{'md5'}.sh");

		# run command if exec limit is not exceeded
		if ($config->{'limit'} > scalar(keys %pids)) {
			# remove job from queue which wait to exec if exists
			if (-e "$dir/$$in{'md5'}.sh") {
				# add job into queue which wait to exec
				unless ($queue{$$in{'md5'}}) {
					$tm = gettimeofday();
					%new_pid = (
						'log' 	=> "$dir/$$in{'md5'}.log",
						'killed'=> 0,
						'time'	=> $tm,
						'md5'	=> $$in{'md5'}
					);

					# add pid into pids hash
					$status = move_job('new', 'pids', \%new_pid);
					unless ($status) {
						write_log("Can not add new job into pids $$in{'md5'}. status = '$status'");
						return 0, 'Can not add new job into pids';
					}
				}
				else {
					# move pid to pids hash
					$status = move_job('queue', 'pids', $$in{'md5'});
					unless ($status) {
						write_log("End create job $$in{'md5'}. status = '$status'");
						return 0, '';
					}
				}
			}
			else {
				write_log($config->{'messages'}->{'can_not_create_job'}."$dir/$$in{'md5'}.sh");
				return 0, '';
			}
		}
		else {
			# add job into queue which wait to exec
			$tm = gettimeofday();
			%new_pid = (
				'log' 	=> "$dir/$$in{'md5'}.log",
				'killed'=> 0,
				'time'	=> $tm,
				'md5'	=> $$in{'md5'}
			);

			# add pid into queue hash
			$status = move_job('new', 'queue', \%new_pid);
			unless ($status) {
				write_log("Can not add new job into queue $$in{'md5'}. status = '$status'");
				return 0, 'Can not add new job into queue';
			}
		}

		# return name of the job
		write_log("End create job $job");

		return $$in{'md5'}, '';
	}
	else {
		# delete pid from queue hash
		$status = move_job('delete', 'queue', $$in{'md5'});
		unless ($status) {
			write_log("Can not delete job from queue $$in{'md5'}. status = '$status'");
			return 0, 'Can not delete job from queue';
		}

		write_log("End create job $job. Can not create dir for job");

		return 0, $config->{'messages'}->{'can_not_create_dir'};
	}
}

sub kill_job {
	my ($pid, $list, $status, $store, @list, @tmp);
	$pid = shift;

	# find pids of all running jobs for current pid
	$list = ps_jobs($pid);

	# get list of all running jobs for current pid
	@list = split("\n", $list);

	# kill all running jobs for current pid
	map {
		# find pid
		@tmp = ();
		s/\s+/ /goi;
		@tmp = split(" ", $_);

		# kill found pid job
		if ($tmp[1]) {
			$tmp[1] =~ /\D/goi;
			kill_jobs($tmp[1]);
			`pkill -TERM -P $tmp[1]`;
		}
	} (@list);

	# delete job from queues list
	$status = 1;
	if (ref($queue{$pid}) eq 'HASH') {
		# move pid from queue hash
		$status = move_job('queue', 'done', $pid);
		unless ($status) {
			write_log("Can not move job from queue $pid into done. status = '$status'");
			return 0, 'Can not move job from queue into done';
		}
	}
	elsif (ref($pids{$pid}) eq 'HASH') {
		# move pid to done hash & write interupt message into job-log
		$status = move_job('pids', 'done', $pid, 'killed');
		unless ($status) {
			write_log("Can not move job from pids $pid into done. status = '$status'");
			$status = 0;
		}
	}
	elsif (ref($done{$pid}) eq 'HASH') {
		# write interupt message into job-log
		$status = move_job('done', 'done', $pid, 'killed');
		unless ($status) { $status = 0; }
	}

	return $status;
}

sub list_of_preset {
	my ($f, $mess, @list);

	@list = ();
	$mess = '';
	if (-d "$config->{'templates_dir'}") {
		opendir(DIR, "$config->{'templates_dir'}") or $mess = "Can't open directory $config->{'templates_dir'}: $!\n";
			while ($f = readdir(DIR)) {
				unless ($f =~ /^\./) {
					$f =~ s/\.txt\.ep//;
					push @list, $f;
				}
			}
		closedir(DIR) or $mess = "Can't close directory $config->{'templates_dir'}: $!\n";
	}

	return \@list, $mess;
}

############ Subs ############
sub run_job {
	my $name = shift;

	write_log("Run job $name");

	if ($name) {
		$name =~ s/\.\w+$//;
		chmod_plus("$name.sh");
		run_background("$name.sh", "$name.log");
		chmod_minus("$name.sh");
	}

	write_log("End job $name");

	return;
}

sub check_job {
	my ($pid, $status);
	$pid = shift;

	$status = 0;
	if ($pid) {
		if (ref($queue{$pid}) eq 'HASH') { $status = 1; }
		elsif (ref($pids{$pid}) eq 'HASH') { $status = 1; }
		elsif (ref($done{$pid}) eq 'HASH') { $status = 1; }
		if ($status) { return 1, $config->{'messages'}->{'exists_job'}; }
	}
	else {
		return $status, $config->{'messages'}->{'has_not_pid'};
	}

	return 0, '';
}

sub create_md5 {
	my ($in, $md5);
	$in = shift;

	map {
		if (ref($$in{$_}) ne 'HASH') {
			if ($$in{$_}) {
				if ($md5) {
					$md5 .= $$in{$_};
				}
				else{
					$md5 = $$in{$_};
				}
			}
		}
	} (sort {$a cmp $b} keys %{$in});
	$md5 = md5_hex($md5.time);

	return $md5;
}

sub write_log {
	my $data = shift;

	if ($config->{'debug'}) {
		$data = time() . ": $data";

		open (FILE, ">>$config->{'log'}");
			print FILE "$data\n";
		close (FILE);
	}
}

1;
