package common;

use strict;
use warnings;

use Socket;
use IO::Select;
use IO::Handle;
use constant DEBUG => 0;

use Data::Dumper;
use JSON::XS;

use Mojo::Home;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK $config $messages $childs $selread $pids ); # @pids 

use utf8;
$| = 1;

@ISA = qw( Exporter );
@EXPORT = qw(
	$config $messages $childs $selread $pids 
	&info_job &create_job &kill_process &dbg_print
);

my ($config, $messages, $childs, $selread, $pids); # , @pids

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0
		#'SSL_VERIFY_NONE'
	);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';

	$selread = IO::Select->new();
};

# set max num of childs
$childs = 8;
#@pids = ();
$pids = {};

sub info_job {
	my ($line, $read, $pid, $sel);
	$pid = shift;

	if ($pids->{$pid}) {
		# prepare read stored handle
		$sel = IO::Select->new($pids->{$pid}->{child_fh});

		$line = '';
		while ($sel->can_read()) {
			# choose handle & read output
			my $fh = $pids->{$pid}->{child_fh};
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

			last if defined($line);
			chomp $line;
		}

		return ($pids, $line);
	}
	return ($pids, 0);
}

sub create_job {
	my ($childid, $hchild, $hparent, $job, $line);
	$job = shift;

	# check number of jobs
	if ($childs <= scalar(keys %$pids)) {
		return ($pids, 0);
	}

	# create socket for job
	my $pair  = {
		child_fh	=> undef,
		parent_fh	=> undef,
		pid			=> undef
	};

	socketpair($pair->{child_fh}, $pair->{parent_fh}, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";

	$childid = fork;
	die "cannot fork" if ($childid == -1);

	$pair->{pid} = $childid;
	$pair->{command} = $job;

	# redirect child outout into opened socket
	unless ($childid) {
		# child
		open STDIN, "<&", $pair->{parent_fh};
		open STDOUT, ">&", $pair->{parent_fh};
		open STDERR, ">&", $pair->{parent_fh};
		close $pair->{parent_fh};
		close $pair->{child_fh};

		# close inherited handles
		for my $h ($selread->handles) {
			$selread->remove($h);
			close $h;
		}

		exec($job);
	}

	if ($childid) {
		$pids->{$childid} = $pair;
	}

	close $pair->{parent_fh};
	$selread->add($pids->{$childid}->{child_fh});

	return ($pids, $childid);
}

sub kill_process {
	my ($pid);
	$pid = shift;

	# close handles for child process
	close $pids->{$pid}->{parent_fh};
	close $pids->{$pid}->{child_fh};

	# delete child from list
	delete $pids->{$pid};

	kill 9, $pid;
	wait;
}

# debug output
sub dbg_print {
	my ($msg);
	$msg = shift;

	print STDERR "$msg\n" if (DEBUG);
}

1;
