package common;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Data::Dumper;

#use Mojo::Home;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK $config $messages $queue_l $pids_l $done_l );

use utf8;
$| = 1;

use libbash;

our @ISA = qw( Exporter );
our @EXPORT = qw(
	$config $messages $queue_l $pids_l $done_l 
	&done_job &info_job &create_job &kill_job &get_pdf_res &load_queues &store_queues
);

my %queue_h = ();
my %pids_h = ();
my %done_h = ();
our ($config, $messages, $queue_l, $pids_l, $done_l);

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0
		#'SSL_VERIFY_NONE'
	);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';

	$queue_l = \%queue_h;
	$pids_l = \%pids_h;
	$done_l = \%done_h;
};

############ queues ############

sub store_queues {
	my ($type, $pid, $status);
	($type, $pid) = @_;

	$status = store_queue('queue');
	if ($status) { return 'queue'; }
	$status = store_queue('pids');
	if ($status) { return 'pids'; }
	$status = store_queue('done');
	if ($status) { return 'done'; }
}

sub load_queues {
	$queue_l = load_queue('queue');
	$pids_l = load_queue('pids');
	$done_l = load_queue('done');
}

sub load_queue {
	my ($type, $link, $line, $key, $val, $pid, $status);
	$type = shift;

	# when read all jobs from storage will be replaced exists keys and values
	if ($type eq 'queue') { $link = \%queue_h; }
	elsif ($type eq 'pids') { $link = \%pids_h; }
	elsif ($type eq 'done') { $link = \%done_h; }

	if (-e "$config->{'storage_dir'}/$type") {
		open (FILE, "<$config->{'storage_dir'}/$type") or $status = 0;
			 while (chomp($line = <FILE>)) {
				($key, $val) = split("\t", $line);

				# check key and value
				if ($key && $val) {
					unless ($key =~ /\D/) {
						$$link{$key} = $val;
					}
				}
			} (keys %{$link});
		close (FILE) or $status = 0;

	}

	return $link;
}

sub store_queue {
	my ($type, $link, $line, $cnt, $status);
	$type = @_;

	$status = 1;

	# check folder for queues
	unless (-e "$config->{storage_dir}/$type") {
		$status = 2;
	}
	else {
		# create link to queue which are store (queue pids done)
		if ($type eq 'queue') { $link = \%queue_h; }
		elsif ($type eq 'pids') { $link = \%pids_h; }
		elsif ($type eq 'done') { $link = \%done_h; }
		else { $status = 3; }

		$cnt = scalar(keys %{$link});
		if (($status == 1)&&($cnt)) {
			open (FILE, ">$config->{'storage_dir'}/$type") or $status = 0;
				map {
					$line = join("\t", ($_, $$link{$_}));
					if ($cnt) { $line .= "\n"; }
					print FILE $line;
				} (keys %{$link});
			close (FILE) or $status = 0;
		}
	}

	return $status;
}

sub move_job {
	my ($from_type, $to_type, $pid) = @_;

#	$queue_l = load_queue('queue');
#	$pids_l = load_queue('pids');
#	$done_l = load_queue('done');

	if ($from_type eq 'queue') {
		if (exists $queue_h{$pid}) {
			$pids_h{$pid} = $queue_h{$pid};
			delete $queue_h{$pid};
		}
		else { return 0; }
	}
	elsif ($from_type eq 'pids') {
		if (exists $pids_h{$pid}) {
			$done_h{$pid} = $pids_h{$pid};
			delete $pids_h{$pid};
		}
		else { return 0; }
	}
	elsif ($from_type eq 'done') {
		if (exists $done_h{$pid}) { delete $done_h{$pid}; }
		else { return 0; }
	}
	else { return 0; }

	return 1;
}

sub done_job {
	my ($line, $pid, $status);
	$pid = shift;

	# Check exists job & output data from them
	if (exists $pids_h{$pid}) {
		# move pid to done hash
		$status = move_job('pids', 'done', $pid);
		unless ($status) { return 0; }

		# store queues
		$status = store_queues();
		if ($status) { return $status; }

		return 1;
	}
	else {
		return 0;
	}
}

sub info_job {
	my ($line, $pid, $status);
	$pid = shift;

	# Read list of job after reloading mode
	$status = load_queues();
	unless ($status) { return '', 0; }

	if (exists $pids_h{$pid}) {
		# read log from current job
		if (-e $pids_h{$pid}) {
			$line = `cat $pids_h{$pid}`;
		}
		else { return '', 0; }

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
	my ($self, $childid, $hchild, $hparent, $cmd, $line, $job, $status, $error, $in);
	($self, $job, $in) = @_;

	# set soure dir variable
	unless ($$in{'source'}) {
		$$in{'source'} = $config->{'output_dir'};
	}

	# set up md5 hash for indentify current job
	$$in{'md5'} = create_md5(\%in);
	unless ($$in{'md5'}) {
		return 0, '';
	}

	# check exists job and return if exists
	($status, $error) = check_job($$in{'md5'});
	if ($status) {
		return 0, $error;
	}

	# check GUI or API
	if (-e "$config->{'home_dir'}/layouts/$job") {
		$cmd = $self->render_to_string(	
			"layouts/$job",
			format	=> 'txt',
			config	=> $config,
			in		=> \%in
		);
	}
	else {
		$cmd = $job;
	}

	# add callback request
	$cmd .= ";\ncurl http://queue/done?pid=$$in{'md5'};\n";

	# check number of jobs
	my $dir = "$config->{'output_dir'}/$$in{'md5'}";
	if ($config->{'limit'} <= scalar(keys %{$pids_l})) {
		# add job into queue which wait to exec
		$queue_h{$$in{'md5'}} = "$dir/$$in{'md5'}.log";
	}

	# run command in background & write output into file
	makedir($dir);
	echo_command($cmd, "$dir/$$in{'md5'}.sh");
	chmod_plus("$dir/$$in{'md5'}.sh");
	run_background("$dir/$$in{'md5'}.sh", "$dir/$$in{'md5'}.log");
	chmod_minus("$dir/$$in{'md5'}.sh");
# ???????? create exec check

	if (-d "$dir") {
		# store name of new job md5 hash into job storage and path for output data
		$pids_h{$$in{'md5'}} = "$dir/$$in{'md5'}.log";

		# reload list of jobs

		# return name of the job
		return $$in{'md5'}, '';
	}
	else {
		return 0, '';
	}
}

sub check_job {
	my ($pid, $status);
	$pid = shift;

	$status = 0;
	if ($pid) {
		if (exists $queue_h{$pid}) { $status = 1; }
		if (exists $pids_h{$pid}) { $status = 1; }
		if (exists $done_h{$pid}) { $status = 1; }
		if ($status) { return 1, $config->{'messages'}->{'exists_job'}; }
	}
	else {
		return $status, $config->{'messages'}->{'has_not_pid'};
	}

	return 0, '';
}

sub kill_job {
	my ($pid, $list, @list, @tmp);
	$pid = shift;

	if ($pids_h{$pid}) {
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

		# write interupt message into job-log
# ????? create list of killed jobs

		# store list of running job
# ????????

		# delete gob from queue list
# ????? create list of killed jobs
		delete $queue_h{$pid} if exists $queue_h{$pid};
		delete $pids_h{$pid} if exists $pids_h{$pid};
		delete $done_h{$pid} if exists $done_h{$pid};

		return 1;
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

sub get_pdf_res {
	my ($file, $line, $resp, $config, %out);
	$file = shift;
	$config = shift;

	pdf_info($file);
#	$resp = `pdfinfo -f 1 -l -1 $file 2>&1`;

	$out{'error'} = 0;
	if ($resp =~ /Incorrect password/) {
		$out{'error'} = "55";
		$out{'reason'} = $config->{'messages'}->{'password_protected'};
		return \%out;
	}
	if (($resp =~ /Error/) and (! $resp =~ /Expected the optional/)) {
		$out{'error'} = "51";
		$out{'reason'} = $config->{'messages'}->{'expected_optional'};
		return \%out;
	}
	if ($resp =~ /.*Pages\:.*?(\d+)/) {
		$out{'num_pages'} = $1;
	}
	if ($resp =~ /Page.*?size\:.*?(\d+\s+x\s+\d+).*?pts/) {
		($out{'width'}, $out{'height'}) = split(/\s+x\s+/, $1);
		unless ($out{'width'} || $out{'height'}) {
			$out{'error'} = "404";
			$out{'reason'} = $config->{'messages'}->{'not_exists_resolution'};
			return \%out;
		}
		$out{'width'} =~ s/\D//goi;
		$out{'height'} =~ s/\D//goi;
	}

	if ($out{'width'} > $out{'height'}) { $out{'orientation'} = "L"; }
	else { $out{'orientation'} = "P"; }

	## May have variable page sizes within the same document so always use custom
	$out{'paper_type'} = "custom";

	return \%out;
}

1;
