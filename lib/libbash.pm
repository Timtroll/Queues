package common;

use strict;
use warnings;

use Exporter();

use utf8;
$| = 1;

our @ISA = qw( Exporter );
our @EXPORT = qw(
	&run_background &kill_jobs &ps_jobs &echo_command &cat &makedir &chmod_plus &chmod_minus &pdf_info
);

sub run_background {
	my ($file, $log, $line);
	$file = shift;
	$log = shift;

print "$file > $log \&\n";
	$line = `$file > $log &`;

	return $line;
}

sub kill_jobs {
	my ($pid, $line);
	$pid = shift;

	$line = `pkill -TERM -P $pid`;

	return $line;
}

sub ps_jobs {
	my ($pid, $line);
	$pid = shift;

	$line = `ps -aux| grep $pid`;

	return $line;
}

sub echo_command {
	my ($file, $cmd, $line);
	$cmd = shift;
	$file = shift;

	$line = `echo '$cmd' >  $file`;

	return $line;
}

sub cat {
	my ($file, $line);
	$file = shift;

	$line = `cat $file`;
	utf8::decode($line) if ($line);

	return $line;
}

sub makedir {
	my ($file, $line);
	$file = shift;

	$line = `mkdir $file`;

	return $line;
}

sub chmod_plus {
	my ($file, $line);
	$file = shift;

	$line = `chmod +x $file`;

	return $line;
}

sub chmod_minus {
	my ($file, $line);
	$file = shift;

	$line = `chmod -x $file`;

	return $line;
}

sub pdf_info {
	my ($file, $line);
	$file = shift;

	$line = `pdfinfo -f 1 -l -1 $file 2>&1`;

	return $line;
}

1;

