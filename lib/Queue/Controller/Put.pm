package Queue::Controller::Put;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use JSON::XS;
use Data::Dumper;

use common;

sub queue_put {
	my ($self, $json_xs, $out, $ext, $error, $queue_id, %in);
	$self = shift;

	# get fieilds from request & check required fields
	%in = ();
	$out = {};
	$error = 0;
	foreach (keys %{$config->{put}}) {
		$in{$_} = $self->param($_);
		if ($config->{put}->{$_} && !$in{$_}) {
			# set up 400 error if not exists required field
			$error++;
			$out->{'status'} = 400;
			unless ($out->{'reason'}) {
				$out->{'reason'} = $config->{messages}->{'not_exists_fields'}." $_";
			}
			else {
				$out->{'reason'} .= " $_";
			}
		}

		# decode json->obj if exists
		if (($_ eq 'options') && (ref($in{$_}) eq 'HASH') && !$error) {
			$json_xs = JSON::XS->new();
			$json_xs->utf8(1);
			$in{$_} = $json_xs->decode($in{$_});
		}
	}
print Dumper(\%in);

	# check supported conversion type
	if (exists $config->{'conversion_type'}->{$in{'conversion_type'}} && !$error) {
		# check extention of source file
		$ext = $config->{'conversion_type'}->{$in{'conversion_type'}};
		unless ($in{'source'} =~ /\.$ext$/) {
			$error++;
			$out = {
				'status'	=> 415,
				'reason'	=> $config->{messages}->{'not_support_media'}.$in{'conversion_type'}
			};
		}
	}

	# set up out image size & resolution
	unless ($in{'resolution'}) { $in{'resolution'} = 160; }
	if ($in{'size'}{'width'} && $in{'size'}{'height'}) {
		$in{'size_sum'} = "$in{'size'}{'width'}x$in{'size'}{'height'}";
	}
	else {
		$in{'size_sum'} = '900x900';
	}

	# make conversion
	unless ($error) {
		if ($in{'conversion_type'}) {
			if (-e "$config->{'home_dir'}/layouts/$in{'conversion_type'}") {
				# get shell commands from templates
				$queue_id = $self->create_job($in{'conversion_type'}, \%in);
			}
			else { $error++; }
=comment
		if ($in{'conversion_type'} eq 'pdf2jpg') {
			# set up command line for making conversion to include it in pipe
			# create ./tmp dir
			# split input_name.pdf -> input_name.\d.pdf
			# delete txt description
			# convert one by one input.name.\d.pdf files -> input_name.\d.jpg & input_name.\d.swf & resize input_name.\d.jpg -> input_name.\d.jpg including srgb.icm schema
			# move ./tmp files into source dir
			# delete ./tmp dir

			$queue_id = $self->create_job('pdf2jpg', \%in);
#			$queue_id = pdf2jpg($self, \%in, $config);
		}
		elsif ($in{'conversion_type'} eq 'psd2jpg') {
			# set up command line for making conversion to include it in pipe
			# resize input_name.jpg -> input_name.jpg including srgb.icm schema if exists
			# move ./tmp files into source dir
			# delete ./tmp dir

			$queue_id = $self->create_job('psd2jpg', \%in);
#			$queue_id = psd2png(\%in, $config);
		}
=cut
		else { $error++; }

		if ($error) {
			$out = {
				'status'	=> 415,
				'reason'	=> $config->{messages}->{'not_support_conversion'}.$in{'conversion_type'}
			};
		}
		else {
			# check created job id
			unless ($queue_id) {
				$error++;
				$out = {
					'status'	=> 409,
					'reason'	=> $config->{messages}->{'not_created_job'}
				};
			}
		}
	}

	unless ($error) {
		$out = {
			'status'	=> 201,
			'queue_id'	=> $queue_id,
			'start_time'=> time()
		};
	}

	$self->render( json => $out );
}

1;
