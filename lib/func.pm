package func;

use strict;
use warnings;

use Data::Dumper;

use common;

use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK );

use utf8;
$| = 1;

@ISA = qw( Exporter );
@EXPORT = qw(
	&get_pdf_res &pdf2jpg
);

sub pdf2jpg {
	my ($self, $in, $config, $size, $res,
		$page_output, 
		$cmd, $pids, $childid);
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
	my $tmp_dir = $config->{tmp_dir};
	if ($$in{'size'}{'width'} && $$in{'size'}{'height'}) {
		$size = "$$in{'size'}{'width'}x$$in{'size'}{'height'}";
	}
	else {
		$size = '900x900';
	}

	$cmd = $self->render_to_string(	
		'layouts/pdf2jpg',
		format	=> 'txt',
		config	=> $config,
		size	=> $size,
		in		=> $in
	);
	$cmd =~ s/(\r|\n)//goi;
print "$cmd\n";

	($cmd, $childid) = create_job($cmd);

	return $childid;
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
