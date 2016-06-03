package common;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Data::Dumper;

use Mojo::Home;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK $config $messages $pids );

use utf8;
$| = 1;

our @ISA = qw( Exporter );
our @EXPORT = qw(
	$config $messages $pids 
	&done_job &info_job &create_job &kill_job &get_pdf_res &pdf2jpg
);

our ($config, $messages, $pids);
my %pids = ();

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0
		#'SSL_VERIFY_NONE'
	);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

############ queues ############

sub done_job {
	my ($line, $pid);
	$pid = shift;

	# Check exists job & output data from them
	if (exists $pids{$pid}) {
		# store pid for reload application
# ?????????

		# delete job from job queue
		delete $pids{$pid};

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
	my ($childid, $hchild, $hparent, $job, $line, $in, %pair);
	$job = shift;
	$in = shift;

	# check md5 hash
	unless ($$in{'md5'}) {
		return 0;
	}

	# add callback request
	$job .= "\ncurl http://queue/done?pid=$$in{'md5'};\n";

	# check number of jobs
	if ($config->{'limit'} <= scalar(keys %{$pids})) {
		return 0;
	}

	# run command in background & write output into file
# ???????? create exec check
	`mkdir $$in{'output'}/$$in{'md5'}`;
	`echo '$job' > $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh`;
	`chmod +x $$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh`;
	`$$in{'output'}/$$in{'md5'}/$$in{'md5'}.sh > $$in{'output'}/$$in{'md5'}/$$in{'md5'}.log &`;
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
			# find pid
			s/\s+/ /goi;
			@tmp = split(" ", $_);
			$tmp[1] =~ /\D/goi;

			# kill found pid job
			`kill -9 $tmp[1]`;
# ???????? create exec check
			@tmp = ();
		}

		# write interupt message into job-log
#????????

		# delete gob from list
		delete $pids{$pid};
#		$pids = \%pids;

		return 1;
	}
	else {
		return 0;
	}
}

############ conversions ############

sub pdf2jpg {
	my ($self, $in, $config, $cmd, $id);
	$self = shift;
	$in = shift;
	$config = shift;

	# set up command line for making conversion to include it in pipe
	# create ./tmp dir
	# split input_name.pdf -> input_name.\d.pdf
	# delete txt description
	# convert one by one input.name.\d.pdf files -> input_name.\d.jpg & input_name.\d.swf & resize input_name.\d.jpg -> input_name.\d.jpg including srgb.icm schema
	# move ./tmp files into source dir
	# delete ./tmp dir

	# set up out image size & resolution
	unless ($$in{'resolution'}) { $$in{'resolution'} = 160; }
	if ($$in{'size'}{'width'} && $$in{'size'}{'height'}) {
		$$in{'size_sum'} = "$$in{'size'}{'width'}x$$in{'size'}{'height'}";
	}
	else {
		$$in{'size_sum'} = '900x900';
	}

	# create output dir
	$$in{'source_dir'} = $$in{'source'};
	if ($$in{'source_dir'} =~ /\//) {
		$$in{'source_dir'} =~ s/\/.*?$//;
	}

	# set up md5 hash for indentify current job
	$$in{'md5'} = md5_hex($$in{'source'}.time());

	$cmd = $self->render_to_string(	
		'layouts/pdf2jpg',
		format	=> 'txt',
		config	=> $config,
		in		=> $in
	);

	$id = create_job($cmd, $in);
print Dumper(\%pids);

	return $$in{'md5'};
}

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

1;
