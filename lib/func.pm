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
	my ($in, $config, $size, $res,
		$page_output, 
		$cmd);
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
	$cmd = qq~
echo "mkdir $config->{'tmp_dir'}"; \
mkdir $config->{tmp_dir}; \
echo "$config->{'exec_apps'}->{'pdftk'} $$in{'source'} burst output $config->{'tmp_dir'}/%04d.pdf verbose"; \
$config->{'exec_apps'}->{'pdftk'} $$in{'source'} burst output $config->{'tmp_dir'}/%04d.pdf verbose; \
echo "rm $config->{'tmp_dir'}/doc_data.txt"; \
rm $config->{'tmp_dir'}/doc_data.txt; \
for i in `ls $config->{tmp_dir}/*[0-9].pdf`; \
do \
echo "$config->{'exec_apps'}->{'pdf2swf'} -T 9 -w \$i -O1 $config->{tmp_dir}/out.swf";\
$config->{'exec_apps'}->{'pdf2swf'} -T 9 -w \$i -O1 $config->{'tmp_dir'}/out.swf; \
echo "$config->{'exec_apps'}->{'gs'} -dPDFSETTINGS=/printer -dColorImageResolution=72 -dSAFER -dBATCH -dNOPAUSE -sDEVICE=jpeg -r160 -sOutputFile=$config->{'tmp_dir'}/out.jpg \$i";\
$config->{'exec_apps'}->{'gs'} -dSAFER -dBATCH -dNOPAUSE -sDEVICE=jpeg -r160 -sOutputFile=$config->{'tmp_dir'}/out.jpg \$i; \
echo "$config->{'exec_apps'}->{'convert'} $config->{tmp_dir}/out.jpg -resize $size -profile $config->{'icm_profile'} $config->{'tmp_dir'}/out.jpg";\
$config->{'exec_apps'}->{'convert'} $config->{'tmp_dir'}/out.jpg -resize $size -profile $config->{'icm_profile'} $config->{tmp_dir}/out.jpg; \
done; \
echo "cp -invR $config->{'tmp_dir'} $$in{'output'}";\
cp -invR $config->{'tmp_dir'} $$in{'output'}; \
echo "rm -R $config->{'tmp_dir'}";\
rm -R $config->{'tmp_dir'};~;

	my ($pids, $childid) = create_job($cmd);
print "$pids, $childid\n";

=comment
	# get pdf resolution
	$res = get_pdf_res($$in{'source'}, $config);
print Dumper($res);

	$md5_dir = substr($media_md5, 0, 3);
	$thumb_dir = $proxy_path.$proxy_drive[$media_drive].$md5_dir."/";

	# if pdf has not password protection
	if ($$res{'error'} != 55) {
		# split suorce pdf to pages
		$page_output = $$in{'source'};
		$page_output =~ /^.*\/(.*?)\.\w+/;
		$page_output = $1 .".%04d";
		$proxy = "$thumb_dir/$media_md5.$page_num.jpg";
		$cmd = "pdftk $$in{'source'} burst output ".$config->{'tmp_dir'}."/$page_output.pdf";
print "$cmd\n";

		# get list of pages

			# convert pdf page to swf
			$cmd = "/usr/local/bin/pdf2swf -T 9 -w $page -o $swf_out";

			# convert pdf page to jpg
			unless ($$in{'source'}) {
				$$in{'source'} = 72;
			}
			$thumb_cmd = "/usr/bin/gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=jpeg -r$$in{'source'} -sOutputFile=$proxy $page";
	}
	else {
	}
=cut

	return;
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
