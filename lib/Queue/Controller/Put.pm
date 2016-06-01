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
		if (($_ eq 'size') && $in{$_} && !$error) {
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

	# make conversion
	unless ($error) {
		if ($in{'conversion_type'} eq 'pdf2jpg') {
			$queue_id = pdf2jpg($self, \%in, $config);
		}
		elsif ($in{'conversion_type'} eq 'psd2jpg') {
			$queue_id = psd2jpg(\%in, $config);
		}
		else {
			$error++;
			$out = {
				'status'	=> 415,
				'reason'	=> $config->{messages}->{'not_support_conversion'}.$in{'conversion_type'}
			};
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
