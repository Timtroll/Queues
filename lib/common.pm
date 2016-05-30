package common;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Socket;
use IO::Select;
use IO::Handle;
use constant DEBUG => 0;

use Data::Dumper;
use JSON::XS;

use Mojo::Home;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK $config $messages $childs $selread $pids );

use utf8;
$| = 1;

our @ISA = qw( Exporter );
our @EXPORT = qw(
	$config $messages $childs $selread $pids 
	&info_job &create_job &kill_process &dbg_print &get_pdf_res &pdf2jpg
);

our ($config, $messages, $childs, $selread, $pids);
my (%pids);

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0
		#'SSL_VERIFY_NONE'
	);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';

	$selread = IO::Select->new();
};

############ queues ############

# set max num of childs
$childs = 8;
%pids = ();

sub info_job {
	my ($line, $read, $pid, $sel);
	$pid = shift;

	if ($pids{$pid}) {
		# prepare read stored handle
		$sel = IO::Select->new($pids{$pid}{child_fh}, undef, undef, 0);

		$line = '';
		while ($sel->can_read(5)) {
			# choose handle & read output
			my $fh = $pids{$pid}{child_fh};
			sysread($fh, $line, 64*1024, length($line));

# ??????????????
# we have to store last reply

			# find last line in the output
			if (!$line) {
				$sel->remove($fh);
				close($fh);
				$line = undef;

				kill_process($pid);
			}
			else {
				my @tmp = split("\n", $line);
				$line = pop @tmp;
				@tmp = ();
			}

#			last if defined($line);
			last if $line;
			chomp $line;
		}

		$pids = \%pids;
		return $line;
	}

	$pids = \%pids;
	return 0;
}

sub create_job {
	my ($childid, $hchild, $hparent, $job, $line, %pair);
	$job = shift;

	# check number of jobs
	if ($childs <= scalar(keys %pids)) {
		return 0;
	}

	# create socket for job
	%pair  = (
		child_fh	=> undef,
		parent_fh	=> undef,
		pid			=> undef
#		md5			=> md5_hex($job)
	);

	socketpair($pair{child_fh}, $pair{parent_fh}, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";

	$childid = fork;
	die "cannot fork" if ($childid == -1);

	$pair{pid} = $childid;
	$pair{command} = $job;

	# redirect child outout into opened socket
	unless ($childid) {
		# child
		open STDIN, "<&", $pair{parent_fh};
		open STDOUT, ">&", $pair{parent_fh};
		open STDERR, ">&", $pair{parent_fh};
		close $pair{parent_fh};
		close $pair{child_fh};

		# close inherited handles
		for my $h ($selread->handles) {
			$selread->remove($h);
			close $h;
		}

		exec("$job $childid");
	}

	if ($childid) {
		$pids{$childid} = { %pair };
	}

	close $pair{parent_fh};
	$selread->add($pids{$childid}{child_fh});

	$pids = \%pids;
	return ($childid);
}

sub kill_process {
	my ($pid);
	$pid = shift;

	# close handles for child process
	close $pids{$pid}{parent_fh};
	close $pids{$pid}{child_fh};

	# delete child from list
	delete $pids{$pid};

	kill 9, $pid;
	wait;

	$pids = \%pids;
}

# debug output
sub dbg_print {
	my ($msg);
	$msg = shift;

	print STDERR "$msg\n" if (DEBUG);
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

	# set up omut image size & resolution
	unless ($$in{'resolution'}) { $$in{'resolution'} = 160; }
	if ($$in{'size'}{'width'} && $$in{'size'}{'height'}) {
		$$in{'size_sum'} = "$$in{'size'}{'width'}x$$in{'size'}{'height'}";
	}
	else {
		$$in{'size_sum'} = '900x900';
	}

	$cmd = $self->render_to_string(	
		'layouts/pdf2jpg',
		format	=> 'txt',
		config	=> $config,
		in		=> $in
	);
	$cmd =~ s/(\r|\n)//goi;
print "$cmd\n";

	$id = create_job($cmd);

	return $id;
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
