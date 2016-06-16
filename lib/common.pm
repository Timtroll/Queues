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
	&done_job &info_job &create_job &kill_job &get_pdf_res &load_queues &store_queues
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

=comment
print Dumper(\%queue);
print Dumper(\%pids);
print Dumper(\%done);
	# load jobs from stored and run Pids-queue
	if (scalar(keys %pids)) {
		# Run jobs from Pids
		my $limit = $config->{'limit'};
		foreach (keys %pids) {
			run_job($pids{$_}->{'log'});
			$limit--;
		}
	}
=cut
};

############ queues ############

sub store_queues {
	my ($type, $pid, $status);
	($type, $pid) = @_;

	if (scalar(keys %queue)) {
		$status = store_queue('queue');
		unless ($status) { return 'queue'; }
	}

	if (scalar(keys %pids)) {
		$status = store_queue('pids');
		unless ($status) { return 'pids'; }
	}

	if (scalar(keys %done)) {
		$status = store_queue('done');
		unless ($status) { return 'done'; }
	}
}

sub load_queues {
	my ($status, @message);

	$status = load_queue('queue');
	unless ($status) { push @message, $config-{'messages'}->{'can_not_open_queue'}."'queue'"; }

	$status = load_queue('pids');
	unless ($status) { push @message, $config-{'messages'}->{'can_not_open_queue'}."'pids'"; }

	$status = load_queue('done');
	unless ($status) { push @message, $config-{'messages'}->{'can_not_open_queue'}."'done'"; }

	# create error messages
	if (scalar(@message)) {
		$messages = join("\n", @message);
	}

	return $status, $messages;
}

sub load_queue {
	my ($type, $link, $line, $json_xs, $val, $pid, $status);
	$type = shift;

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
					if (exists $val->{'md5'}) {
						if ($type eq 'queue') { $queue{$val->{'md5'}} = { %{$val} }; }
						elsif ($type eq 'pids') { $pids{$val->{'md5'}} = { %{$val} }; }
						elsif ($type eq 'done') { $done{$val->{'md5'}} = { %{$val} }; }
					}
				}
			};
		close (FILE) or $status = 0;
	}
	else {
		unlink "$config->{'storage_dir'}/$type";
	}

	return $status;
}

sub store_queue {
	my ($type, $link, $line, $cnt, $json_xs, $status);
	$type = shift;

	$status = 1;

	# check folder for queues
	unless (-d $config->{storage_dir}) {
		return 2;
	}
	else {
		# create link to queue which are store (queue pids done)
		if ($type eq 'queue') { $link = \%queue; }
		elsif ($type eq 'pids') { $link = \%pids; }
		elsif ($type eq 'done') { $link = \%done; }
		else { return 3; }

		$cnt = scalar(keys %{$link});
		if (($status == 1)&&($cnt)) {
			$json_xs = JSON::XS->new();
			$json_xs->utf8(1);

			open (FILE, ">$config->{'storage_dir'}/$type") or $status = 0;
				map {
					if ($type eq 'queue') { $line = $json_xs->encode($queue{$_}); }
					elsif ($type eq 'pids') { $line = $json_xs->encode($pids{$_}); }
					elsif ($type eq 'done') { $line = $json_xs->encode($done{$_}); }
					if ($cnt > 1) { $line .= "\n"; }
					print FILE $line;
					$cnt--;
				} (keys %{$link});
			close (FILE) or $status = 0;
		}
	}

	return $status;
}

sub move_job {
	my ($from_type, $to_type, $pid, $dir, $killed) = @_;

	if ($from_type eq 'queue') {
		if (exists $queue{$pid}) {
			$pids{$pid} = $queue{$pid};
			delete $queue{$pid};

			# run moved job
			run_job($queue{$pid}->{'log'});
		}
		else { return 0; }
	}
	elsif ($from_type eq 'pids') {
		if (exists $pids{$pid}) {
			# delete olderst element from done queue if exceed done-limit
			if (scalar(keys %done) > $config->{'limit_show_done'}) {
				foreach (sort {$done{$a}->{'time'} <=> $done{$b}->{'time'}} keys %done) {
					delete $done{$_};
					last;
				}
			}

			# set status 'killed' if job was kill
			if ($killed) {
				$pids{$pid}->{'killed'} = 1;
			}

			$done{$pid} = $pids{$pid};
			delete $pids{$pid};
		}
		else { return 0; }
	}
	elsif ($from_type eq 'done') {
		if (exists $done{$pid}) {
			# set status 'killed' if job was kill
			if ($killed) {		
				$done{$pid}->{'killed'} = 1;
			}
		}
		else { return 0; }
	}
	else { return 0; }

	return 1;
}

sub done_job {
	my ($line, $pid, $count, $dir, $status);
	$pid = shift;

	# Check exists job & output data from them
	if (exists $pids{$pid}) {
print "$pid = $pids{$pid}\n";
		# move pid to done hash
		$status = move_job('pids', 'done', $pid);
#		unless ($status) { return 0; }

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

		# store queues
		$status = store_queues();
		if ($status =~ /\d/) { return $status; }

		return 1;
	}
	else {
		return 0;
	}
}

sub info_job {
	my ($line, $pid, $link, $status, $mess);
	$pid = shift;

	# Read list of job after reloading mode
	($status, $mess) = load_queues();
	unless ($status) { return $mess, 0; }

	$line = '';
	if (exists $queue{$pid}) { $line = $queue{$pid}->{'log'}; }
	elsif (exists $pids{$pid}) { $line = $pids{$pid}->{'log'}; }
	elsif (exists $done{$pid}) { $line = $done{$pid}->{'log'}; }
	else { $line = undef; }

	if ($link) {
		# read log from current job
		if (-e $link->{'log'}) {
			$line = `cat $link->{'log'}`;
		}
		else { return $config->{'messages'}->{'not_exists_log'}, 0; }

		return $line, 1;
	}
	elsif (-e "$config->{'output_dir'}/$pid/$pid.log") {
		$line = `cat $config->{'output_dir'}/$pid/$pid.log`;

		return $line, 1;
	}
	else {
		return '', 0;
	}
}

sub create_job {
	my ($self, $cmd, $line, $job, $status, $error, $in, $tm, $dir);
	($self, $job, $in) = @_;

	# set soure dir variable
	unless ($$in{'source'}) {
		$$in{'source'} = $config->{'output_dir'};
	}

	# set up md5 hash for indentify current job
	$$in{'md5'} = create_md5($in);
	unless ($$in{'md5'}) {
		return 0, '';
	}

	# check exists job and return if exists
	($status, $error) = check_job($$in{'md5'});
	if ($status) { return 0, $error; }

	# check GUI or API
	if (-e "$config->{'home_dir'}/layouts/$job") {
		$cmd = $self->render_to_string(	
			"layouts/$job",
			format	=> 'txt',
			config	=> $config,
			in		=> $in
		);
	}
	else {
		$cmd = $job;
	}

	# add callback request
	$cmd .= ";\ncurl http://queue/done?pid=$$in{'md5'};\n";

	# check number of jobs
	$dir = "$$in{'source'}/$$in{'md5'}";
	$tm = gettimeofday();
	if (scalar(keys %pids) >= $config->{'limit'}) {
		# add job into queue which wait to exec
		$queue{$$in{'md5'}} = {
			'log' 	=> "$dir/$$in{'md5'}.log",
			'killed'=> 0,
			'time'	=> $tm,
			'md5'	=> $$in{'md5'}
		};
	}
	else {
		# store name of new job md5 hash into job storage and path for output data
		$pids{$$in{'md5'}} = {
			'log' 	=> "$dir/$$in{'md5'}.log",
			'killed'=> 0,
			'time'	=> $tm,
			'md5'	=> $$in{'md5'}
		}
	}

	# prepare command to run and write output into file in background 
	makedir($dir);
	echo_command($cmd, "$dir/$$in{'md5'}.sh");
	chmod_plus("$dir/$$in{'md5'}.sh");

	# run command and write output into file in background
	run_job("$dir/$$in{'md5'}");

print "$dir\n";
	if (-d "$dir") {
		# run command if exec limit is not exceeded
print "$config->{'limit'} > ", scalar(keys %pids), "\n";
		if ($config->{'limit'} > scalar(keys %pids)) {
			# remove job from queue which wait to exec if exists
			if (exists $queue{$$in{'md5'}}) {
print "$dir\n";
				# move pid to done hash
				$status = move_job('queue', 'pids', $$in{'md5'});
				unless ($status) { return 0, ''; }

				# run command and write output into file in background
				run_job($pids{$$in{'md5'}});
			}
		}

		# store queues
		$status = store_queues();
		unless ($status =~ /\d/) { return 0, ''; }

#		# store and reload list of jobs
#		$status = store_queue('queue');
#		unless ($status) { return 'queue'; }
#		$status = store_queue('pids');
#		unless ($status) { return 'queue'; }

# ???????? create exec check

#	# Read list of job after reloading mode
#	$status = load_queues();
#	unless ($status) { return '', 0; }

		# return name of the job
		return $$in{'md5'}, '';
	}
	else {
print "00000\n";
		return 0, '';
	}
}

sub run_job {
	my $name = shift;

	$name =~ s/\..*?$//;
write_log($name);
#	chmod_plus("$name.sh");
write_log(run_background("$name.sh", "$name.log"));
	chmod_minus("$name.sh");

	return;
}

sub check_job {
	my ($pid, $status);
	$pid = shift;

	$status = 0;
	if ($pid) {
		if (exists $queue{$pid}) { $status = 1; }
		elsif (exists $pids{$pid}) { $status = 1; }
		elsif (exists $done{$pid}) { $status = 1; }
		if ($status) { return 1, $config->{'messages'}->{'exists_job'}; }
	}
	else {
		return $status, $config->{'messages'}->{'has_not_pid'};
	}

	return 0, '';
}

sub kill_job {
	my ($pid, $list, $status, $store, @list, @tmp);
	$pid = shift;

	if ($pids{$pid}) {
		# find pids of all running jobs for current pid
		ps_jobs($pid);

		# get list of all running jobs for current pid
		@list = split("\n", $list);

		# kill all running jobs for current pid
		map {
			# find pid
			@tmp = ();
			s/\s+/ /goi;
			@tmp = split(" ", $_);
			$tmp[1] =~ /\D/goi;

			# kill found pid job
			kill_jobs($tmp[1]);
			`pkill -TERM -P $tmp[1]`;
		}  (@list);

		# delete job from queue list
		$status = 1;
		if (exists $queue{$pid}) {
			delete $queue{$pid};
		}
		elsif (exists $pids{$pid}) {
			# move pid to done hash & write interupt message into job-log
			$status = move_job('pids', 'done', $pid, 'killed');
			unless ($status) { $status = 0; }
		}
		elsif (exists $done{$pid}) {
			# write interupt message into job-log
			$status = move_job('done', 'done', $pid, 'killed');
			unless ($status) { $status = 0; }
		}

		# store queues statuses
		if ($status) {
			$store = store_queues();
			if ($store =~ /\d/) { return 0; }
		}

		return $status;
	}
	else {
		return 0;
	}
}

############ Subs ############

sub create_md5 {
	my ($in, $md5);
	$in = shift;

	$md5 = '';
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
	} (keys %{$in});
	$md5 = md5_hex($md5.time());

	return $md5;
}

sub write_log {
	my $data = shift;

	open (FILE, ">>$config->{'log'}");
		print FILE "$data\n";
	close (FILE);
}

1;
