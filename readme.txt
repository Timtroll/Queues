Manufactured by Timothy Zhouravlyuov

Required:
Mojolicious
Mojolicious::Plugin::Database
Mojolicious::Plugin::Config
Digest::MD5
JSON::XS
Time::HiRes

Notice:
- current version optimized to linux Debian
- ability to scale an unlimited amount of processing nodes.
- all sh-command in templates need run in verbose mode (templates placing in /templates/layout folder)
- after changing sh-template need to restart application
- queues saved as three types:
	- Queue - list of jobs befor run
	- Pids - list of running jobs (limitation set in queue.conf)
	- Done - list of finished jobs
	- Kill - list of killed jobs
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
	conversion_type:	pdf2jpg,					(conversion type)
	source:				./test.pdf,					(source file for conversion)
	output:				/home/ouput_dir/,			(output directory for result file/es)
	options: {
		quality:			100,					(quality output file/es)
		resolution:			72,						(resolution output file/es in dpi)
		password:			textpass,				(password for pdf file)
		width:	2000,								(width size of output file/es)
		height:	2000								(height size of output file/es)
	}
}

answer

{
	status:		201,								(status according http standard - 201 created pipe)
	md5:		ccd648ff6a3af3294871244153b05cc8	(md5 hash for indentified job)
	start_time:	1456212884							(time of starting conversion in UNIX format)
}

or ERROR

{
	status:		400,								(status according http standard - bad request )
	reason:		'Required fields does not exists in request'
}
{ status:		404 }								(status according http standard - asking conversion type is not exist )
{ status:		415 }								(status according http standard - asking convestion type is not support )
or
{
	status:		503,								(status according http standard)
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
	md5:		ccd648ff6a3af3294871244153b05cc8		(md5 hash for indentify current job)
}

answer

{
	status:		100,									(status according http standard - 100 continue job)
	message:	'sdf sdf sdf asdf ' 					(last message from executing pipe)
}
or
{
	status:			200,								(status according http standard - 200 - finished job)
	message:		'sdf sdf sdf asdf ',				(last message from executing job)
	output_dir:
	output_files:	[file.jpg, file1.jpg]				(list of output files)
}

or ERROR

{ status:		400 }									(status according http standard - bad request )
{ status:		404 }									(status according http standard - asking job is not exist )
{ status:		410 }									(status according http standard - asking job finished )
{ status:		415 }									(status according http standard - asking job could not convert asking type of media )
or
{
	status:		503,									(status according http standard)
	reason:		'description of error'					(description of error during conversion)
}

=== End example ===



============================================================================
Done action requests
=== Example ===
POST/GET request
url: "/done"
{
	action:		done,
	md5:		ccd648ff6a3af3294871244153b05cc8		(md5 hash for indentify current job)
}

answer

{
	status:			200,								(status according http standard - 200 finished job)
	message:		'Done success',						(last message from executing pipe - for 200 status)
}

or ERROR

{ status:		400 }									(status according http standard - bad request )
{ status:		404 }									(status according http standard - job for done is not exists )
or
{
	status:		503,									(status according http standard)
	reason:		'description of error'
}

=== End example ===


============================================================================
Done action requests
=== Example ===
POST/GET request
url: "/kill"
{
	action:		kill,
	md5:		ccd648ff6a3af3294871244153b05cc8		(md5 hash for indentify current job)
}

answer

{
	status:			200,								(status according http standard - 200 process killed)
	reason:			'asd',								(description of killed reason)
	message:		'Kill success',						(full description of status)
}

or ERROR

{ status:		400 }									(status according http standard - bad request )
{ status:		404 }									(status according http standard - job for kill is not exists )
or
{
	status:		503,									(status according http standard)
	reason:		'description of error'
}

=== End example ===
