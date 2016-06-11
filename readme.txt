Manufactured by Timothy Zhouravlyuov

Notice:
- current version optimized to linux Debian
- ability to scale an unlimited amount of processing nodes.
- all sh-command in templates need run in verbose mode (templates placing in /templates/layout folder)
- after changing sh-template need to restart application
- queues saved as three types:
	- queue for befor running jobs ???????????????
	- queue for current running jobs (limitation set in queue.conf)
	- queue for after running jobs ???????????????
- when read all jobs from storage will be replaced exists keys and values
- application has API and web interface (web interface could be off in queue.conf) ???????????????

Description API requests and response.

============================================================================
Put action requests
=== Example ===
POST/GET request
url: "/put"
{
	action:				put,
	conversion_type:	pdf2jpg,			(conversion type)
	source:				./test.pdf,			(source file for conversion)
	output:				/home/ouput_dir/,	(output directory for result file/es)
	quality:			100,				(quality output file/es)
	resolution:			72,					(resolution output file/es in dpi)
	password:			textpass,			(password for pdf file)
	size: {
		width:	2000,				(width size of output file/es)
		height:	2000				(height size of output file/es)
	}
}

answer

{
	status:		201,								(status according http standard - 201 created pipe)
	queue_id:	4639,								(internal linux queue id for reading messages from opened pipe)
	start_time:	1456212884							(time of starting conversion in UNIX format)
}

or ERROR

{
	status:		400,				(status according http standard - bad request )
	reason:		'Does not exists required fields in request'
}
{ status:		404 }				(status according http standard - asking conversion type is not exist )
{ status:		415 }				(status according http standard - asking convestion type is not support )
or
{
	status:		503,					(status according http standard)
	reason:		'description of error'
}

=== End example ===



============================================================================
Ask action requests
=== Example ===
POST/GET request
url: "/ask"
{
	action:		ask,
	queue_id:	4639,	(internal mojolicious queue id for reading messages from opened pipe)
}

answer

{
	status:		100,				(status according http standard - 100 continue pipe-work)
	message:	'sdf sdf sdf asdf ' (last message from executing pipe)
}
or
{
	status:			200,					(status according http standard - 200 - finished pipe-work)
	message:		'sdf sdf sdf asdf ',	(last message from executing pipe)
	output_dir:
	output_files:	[file.jpg, file1.jpg]	(list of output files)
}

or ERROR

{ status:		400 }				(status according http standard - bad request )
{ status:		404 }				(status according http standard - asking queue is not exist )
{ status:		410 }				(status according http standard - asking queue finished )
{ status:		415 }				(status according http standard - asking queue could not convert asking type of media )
or
{
	status:		503,					(status according http standard)
	reason:		'description of error'	(description of error during conversion)
}

=== End example ===



============================================================================
Read action requests
=== Example ===
POST/GET request
url: "/read"
{
	action:		read,
	queue_id:	4639,		(internal mojolicious queue id for reading messages from opened pipe)
}

answer

{
	status:			200,					(status according http standard - 200 finished pipe-work, 415 unsupported media, 503)
	reason:			'error duering conv',	(error message about finished process - for 415, 503 statuses)
	message:		'sdf sdf sdf asdf ',	(last message from executing pipe - for 200 status)
	output_dir:
	output_files:	[file.jpg, file1.jpg]	(list of output files - for 200 status)
}

or ERROR

{ status:		400 }				(status according http standard - bad request )
{ status:		404 }				(status according http standard - asking conversion type is not exist )
or
{
	status:		503,					(status according http standard)
	reason:		'description of error'
}

=== End example ===

============================================================================
Done action requests
=== Example ===
POST/GET request
url: "/dome"
{
	action:		done,
	md5:		ccd648ff6a3af3294871244153b05cc8		(md5 hash for indentify current job)
}

answer

{
	status:			200,					(status according http standard - 200 finished pipe-work, 415 unsupported media, 503)
	message:		'sdf sdf sdf asdf ',	(last message from executing pipe - for 200 status)
}

or ERROR

{ status:		400 }				(status according http standard - bad request )
{ status:		404 }				(status according http standard - asking conversion type is not exist )
or
{
	status:		503,					(status according http standard)
	reason:		'description of error'
}

=== End example ===
