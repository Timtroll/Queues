package common;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Data::Dumper;

use Mojo::Home;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK $config $messages $queue $pids $done );

use utf8;
$| = 1;

our @ISA = qw( Exporter );
our @EXPORT = qw(
	$config $messages $queue $pids $done 
	&done_job &info_job &create_job &kill_job &get_pdf_res &load_queues &store_queues
);

my %queue = ();
my %pids = ();
my %done = ();
our ($config, $messages, $queue, $pids, $done);
$queue = \%queue;
$pids = \%pids;
$done = \%done;

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0
		#'SSL_VERIFY_NONE'
	);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

############ queues ############

sub load_queues {
	$queue = load_queue('queue');
	$pids = load_queue('pids');
	$done = load_queue('done');
}

sub store_queues {
	my ($type, $pid);
	($type, $pid) = @_;

	$queue = store_queue('queue');
	$pids = store_queue('pids');
	$done = store_queue('done');
}

sub load_queue {
	my ($type, $link, $line, $key, $val, $pid, $status);
	$type = shift;

	# when read all jobs from storage will be replaced exists keys and values
	if ($type eq 'queue') { $link = \%queue; }
	elsif ($type eq 'pids') { $link = \%pids; }
	elsif ($type eq 'done') { $link = \%done; }

	if (scalar(keys %{$link})) {
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
		if ($type eq 'queue') { $link = \%queue; }
		elsif ($type eq 'pids') { $link = \%pids; }
		elsif ($type eq 'done') { $link = \%done; }
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

	$queue = load_queue('queue');
	$pids = load_queue('pids');
	$done = load_queue('done');


}

sub del_job {
	my ($from_type, $to_type, $pid) = @_;

	$queue = load_queue('queue');
	$pids = load_queue('pids');
	$done = load_queue('done');


}

sub done_job {
	my ($line, $pid);
	$pid = shift;

	# Check exists job & output data from them
	if (exists $pids{$pid}) {
		# move pid to done hash
# ?????????

		# store pid for reload application
# ?????????

		# delete job from job queue
#		delete $pids{$pid};

		return 1;
	}
	else {
		return 0;
	}
}

sub info_job {
	my ($line, $pid);
	$pid = shift;

# ?????????? create reading after reloading mode

	if ($pids{$pid}) {
		# read log from current job
		$line = `cat $pids{$pid}`;

		return $line;
	}
	else {
		return 0;
	}
}

sub create_job {
	my ($self, $childid, $hchild, $hparent, $cmd, $line, $job, $in, %tmp);
	($self, $job, $in) = @_;
print "$self, $job, $in\n";
	# create output dir variable
	if ($$in{'source'}) {
		$$in{'source_dir'} = $$in{'source'};
		if ($$in{'source_dir'} =~ /\//) {
			$$in{'source_dir'} =~ s/\/.*?$//;
		}
	}
print Dumper($in);
	# set up md5 hash for indentify current job
	$$in{'md5'} = create_md5($in);
	unless ($$in{'md5'}) {
		return 0;
	}

	# check exists job and return if exists
	if (check_job($$in{'md5'})) {
		return 0;
	}

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
	$cmd .= "\ncurl http://queue/done?pid=$$in{'md5'};\n";

	# check number of jobs
	if ($config->{'limit'} <= scalar(keys %{$pids})) {
		# add job into queue which wait to exec
		$queue{$$in{'md5'}} = { %{$in} };
	}

	# run command in background & write output into file
# ???????? create exec check
print "mkdir $$in{'output'}/$$in{'md5'}\n";
	`mkdir $$in{'output'}/$$in{'md5'}`;
print "echo '$cmd' > $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh\n";
	`echo '$cmd' > $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh`;
print "chmod +x $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh\n";
	`chmod +x $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh`;
print "$$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh > $$in{'output'}/$$in{'md5'}/$$in{'md5'}.log &\n";
	`$$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh > $$in{'output'}/$$in{'md5'}/$$in{'md5'}.log &`;
print "chmod -x $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh\n";
	`chmod -x $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh`;
# ???????? create exec check

	if (-d "$config->{'socket_dir'}/$$in{'md5'}") {
		# store name of new job md5 hash into job storage and path for output data
		$pids{$$in{'md5'}} = "$$in{'output'}/$$in{'md5'}/$$in{'md5'}.log";

		# return name of the job
		$pids = \%pids;
		return $$in{'md5'};
	}
	else {
		return 0;
	}
}

sub check_job {
	my $pid = shift;

	if ($pid) {
		if (exists $queue{$pid}) { return 1; }
		elsif (exists $pids{$pid}) { return 1; }
		elsif (exists $done{$pid}) { return 1; }
	}

	return 0;
}

sub kill_job {
	my ($pid, $list, @list, @tmp);
	$pid = shift;

	if ($pids{$pid}) {
		# find pids of all running jobs for current pid
		$list = `ps -aux| grep $pid`;
# ???????? create exec check

		# get list of all running jobs for current pid
		@list = split("\n", $list);

		# kill all running jobs for current pid
		foreach (@list) {
print "$_\n";
			# find pid
			s/\s+/ /goi;
			@tmp = split(" ", $_);
			$tmp[1] =~ /\D/goi;
print "$tmp[1]\n";
			# kill found pid job
			`kill -9 $tmp[1]`;
print "kill -9 $tmp[1]\n";
# ???????? create exec check
			@tmp = ();
		}

		# write interupt message into job-log
#????????

		# delete gob from list
#		delete $pids{$pid};

		return 1;
	}
	else {
		return 0;
	}
}

############ Subs ############

sub get_pdf_res {
	my ($file, $line, $resp, $config, %out);
	$file = shift;
	$config = shift;

	$resp = `pdfinfo -f 1 -l -1 $file 2>&1`;

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

1;
