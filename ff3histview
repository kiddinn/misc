#!/usr/bin/perl
#		ff3histview
# A script that reads the places.sqlite database that Firefox creates and displays 
# the content of the database in a human readable format
#
# Database information was both found using sqlite directly as well from the web
# site : http://www.firefoxforensics.com/
#
# Author: Kristinn Gudjonsson
# Version: 0.3
# Date : 07/09/09
#
# Copyright 2009 Kristinn Gudjonsson ( kristinn ( a t ) log2timeline (d o t ) net )
# Sort order added by : Richard Monk ( rmonk ( a t ) redhat ( d o t ) com )
#
use strict;
use DBI;
use Time::localtime;
use Getopt::Long; # read parameters
use Encode;
use File::Copy;

# various
my $cnr;
my $cinves;
my $cref;
my $quiet;
my $encoding = 'UTF-8';
my $version = "0.3";
my $db_lock = 0;
my $sort = 'date';
my $revsort;
my $sortorder;

# for printing
my $print_csv;
my $print_html;
my $print_txt;
my $print_help;

# fields of interest
my $url;
my $from_visit;
my $date;
my $visit_type;
my $time_offset = 0;
my $hostname;
my @from;
my $show_hidden = 0;
my $only_typed = 0;

my $db_file;
my $db;
my $sql;
my $result;
my @dump;
my $sth;

if( $ARGV < 0 )
{
	print STDERR "Wrong usage: \n";
	print_help();
	exit 23;
}

# read options
GetOptions( "t:s"=> \$time_offset,
	"encoding:s"=>$encoding,
	"csv"=>\$print_csv,
	"html"=>\$print_html,
	"txt"=>\$print_txt,
	"help|?"=>\$print_help,
	"show-hidden"=>\$show_hidden,
	"only-typed"=>\$only_typed,
	"quiet!"=>\$quiet,
	"sort:s"=> \$sort, 
	"r"=>\$revsort );


# check the print status, we have a preference and only one is active
if( $print_txt )
{
	# if -txt is defined we use that
	$print_html = 0;
	$print_csv = 0;
}
else
{
	# now we need to find preference
	if( $print_html )
	{
		$print_txt = 0;
		$print_csv = 0;
	}
	elsif( $print_csv )
	{
		$print_html = 0;
		$print_txt = 0;
		# CSV printing implies quiet
		$quiet = 1;
	}
	else
	{
		$print_html = 0;
		$print_csv = 0;
		$print_txt = 1;
	}
}

if( $print_help )
{
	print_help();
	exit 0;
}

# read the database file
$db_file = $ARGV[0];

# check the file if it exists
if( !-e $db_file )
{
	print STDERR "File $db_file does not exist.\n";
	print_help();
	exit 2;
}

if ( -e "$db_file-journal" )
{
	# create a new variable to store the temp location
	my $temp = rand();
	$temp = "/tmp/tmp$temp.db";

	print STDERR "Database is locked:\nCopy the file to a different location and try again\n";
	# we need to copy the file to a temp location and start again
	copy( $db_file, $temp ) || die( "Unable to copy database file to a temp location, $temp" );
	$db_file = $temp;

	# indicate that the database is locked.
	$db_lock = 1;
}

# connect to the database
$db = DBI->connect("dbi:SQLite:dbname=$db_file","","") || die( "Unable to connect to database\n" );

# check if this is real Firefox database
$db->prepare( 'SELECT id FROM moz_places LIMIT 1' ) || die( "The database is not a correct Firefox database" );

# we now know that we have a FireFox SQLITE database, let's continue

# start by checking out the variable time_offset (possible to use INTh to indicate hours, and INTm to indicate minutes)
if( $time_offset =~ m/h$/ )
{
	# the input is in hours, so modify it to represent seconds

	# modify the offset

	# chop of the last character (the h representing hour)
	chop( $time_offset );
	if ( $time_offset =~ m/^-?\d+$/ )
	{
		# now  we've confirmed that we are dealing with a number, let's multiply
		$time_offset = $time_offset * 3600;
	}
	else
	{
		# the time offset is badly formed, not XXXh where XXX is an integer
		print STDERR "Time offset is badly formed\n";
		$time_offset = 0;
	}
}

# check to see if the time offset is appended with m, for minutes
if( $time_offset =~ m/m$/ )
{
	# modify the offset
	chop( $time_offset );
	if ( $time_offset =~ m/^-?\d+$/ )
	{
		$time_offset = $time_offset * 60;
	}
	else
	{
		print STDERR "Time offset is badly formed\n";
		$time_offset = 0;
	}
}

# and if someone added s to represent seconds
if( $time_offset =~ m/s$/ )
{
	# just chop off the s for seconds
	chop( $time_offset );
}

##################################################################
# the structure/schema of the moz_places table
##################################################################
# id INTEGER PRIMARY KEY
# url LONGVARCHAR
# title LONGVARCHAR
# rev_host LONGVARCHAR
# visit_count INTEGER DEFAULT 0
# hidden INTEGER DEFAULT 0 NOT NULL, 
# typed INTEGER DEFAULT 0 NOT NULL, 
# favicon_id INTEGER, 
# frecency INTEGER DEFAULT -1 NOT NULL

# structure of moz_historyvisits
# id INTEGER PRIMARY KEY
# from_visit INTEGER
# place_id INTEGER
# visit_date INTEGER
# visit_type INTEGER
# session INTEGER
#-----------------------------------------------------------------


# check to see if we need to read parameters
if( !$quiet )
{
	# now we need to ask questions
	print "Enter case number: ";
	$cnr = <STDIN>;
	print "Case reference: ";
	$cref = <STDIN>;
	print "Investigator name: ";
	$cinves = <STDIN>;
}

# check if we are print using HTML
if( $print_html )
{
	print "
<html>
<head>
	<title>Firefox History</title>
</head>

<body>
<h1 align=\"center\">Firefox history</h1>
<br />
<ul>
	";
	if( !$quiet )
	{
		print "
	<li>Case number: $cnr</li>
	<li>Case reference: $cref</li>
	<li>Investigator: $cinves</li>
		";
	}

	if ( $db_lock )
	{
		print "
<li>The history file is locked so a copy of the database has been made and the copy is being read</li>
<li>[WARNING] We might not have the entire history file since Firefox is either still open or exited without flushing the journal</li>
<li>This history file is taken from the file $db_file (temp location)</li>\n";
	}
	if( $only_typed )
	{
		print "
<li>The script outputs only URLs that have been directly typed by the user into the location/URL bar (typed = 1)</li>
		";
	}
	elsif( $show_hidden )
	{
		print "
<li>The script displays \"hidden\" URLs as well as others, that is a URL that the user did not specifically navigate to</li>
		";
	}

	print "
	<li>Date of run (GMT): ", get_time() , "</li>
	<li>Time offset of history file: ", $time_offset, "s</li>
</ul>
<br/>
<br/>
<table width=\"1240\" align=\"center\" cellpadding=\"0\" cellspacing=\"0\"> 
<tr>
	<th width=\"150\">Date</th>
	<th width=\"150\">Host name</th>
	<th width=\"400\">URL</th>
	<th width=\"40\">Count</th>
	<th width=\"300\">Title</th>
	<th width=\"200\">Notes</th>
</tr>
	";
}

# check to see if we are printing using CSV
if( $print_csv )
{
	# print the header information
	if( $show_hidden )
	{
		# we need to add one more header to the equation
		print "id,URL,Title,Count,Date,From,Hostname,Hidden\n";
	}
	else
	{
		print "id,URL,Title,Count,Date,From,Hostname\n";
	}
}

if ( $print_txt )
{
	print "Firefox 3 History Viewer\n";

	if( !$quiet )
	{
		print "
Case number: $cnr
Case reference: $cref
Investigator: $cinves
		";
	}

	if( $only_typed )
	{
		print "Only showing directly typed in URLs\n";
	}
	elsif( $show_hidden )
	{
		print "Showing hidden URLs as well\n";
	}
	else
	{
		print "Not showing 'hidden' URLS, that is URLs that the user did not specifically navigate to, use -s to show them\n";
	}

	print "
Date of run (GMT): ", get_time(), "
Time offset of history file: $time_offset s

-------------------------------------------------------
Date\t\t\t\tCount\tHost name\tURL\tnotes\n";
}

# Construct the SQL statement to extract the needed data
if( $only_typed )
{
	$sql = "
SELECT moz_historyvisits.id,url,title,visit_count,visit_date,from_visit,rev_host
FROM moz_places, moz_historyvisits
WHERE
	moz_places.id = moz_historyvisits.place_id
	AND moz_places.typed = 1
	";
}
elsif( $show_hidden )
{
	$sql = "
SELECT moz_historyvisits.id,url,title,visit_count,visit_date,from_visit,rev_host,hidden
FROM moz_places, moz_historyvisits
WHERE
	moz_places.id = moz_historyvisits.place_id
	";
}
else
{
	$sql = "
SELECT moz_historyvisits.id,url,title,visit_count,visit_date,from_visit,rev_host
FROM moz_places, moz_historyvisits
WHERE
	moz_places.id = moz_historyvisits.place_id
	AND hidden = 0
	";
}

# Add in the sort method
$sortorder=" ASC";
if( $revsort ) { $sortorder=" DESC"; }

if( $sort eq "date" ) { $sql.=" ORDER BY visit_date" . $sortorder; }
elsif( $sort eq "url" ) { $sql.=" ORDER BY url" . $sortorder . ",visit_date"; } 
elsif( $sort eq "visits" ) { $sql.=" ORDER BY visit_count" . $sortorder . ",url,visit_date"; }



$sth = $db->prepare( $sql );
$result = $sth->execute( );

# go through all of the results
while( @dump = $sth->fetchrow_array() )
{
	# we need to fix the date, so we can represent it correctly
	$date = fix_date( $dump[4] );

	# get the hostname	
	$hostname = fix_hostname( $dump[6] );

	# check to see if we came to the web site from another one
	if( $dump[5] ne 0 )
	{
		@from = get_url( $dump[5] );
	}

	# and then to output the data
	if( $print_txt )
	{
		if( defined @from ) 
		{
			print "$date\t$dump[3]\t$hostname\t$dump[1]\tFrom: $from[0]\n";
		}
		else
		{
			print "$date\t$dump[3]\t$hostname\t$dump[1]\n";
		}
	}
	elsif( $print_csv )
	{
		# sometimes the title contains comma, so delete it		
		$dump[2] =~ s/,/\s/g;	

		# format of the CSV file:
		# ID,URL,Title,Count,Date,From,Hostname (,Hidden)

		# check to see if we are coming from another host
		if( defined @from )
		{
			if( $show_hidden )
			{
				print "$dump[0],$dump[1],", $dump[2], ",$dump[3],$date,$from[0],$hostname,$dump[7]\n";
				#print "$dump[0],$dump[1],", encode( $encoding,$dump[2]), ",$dump[3],$date,$from[0],$hostname\n";
			}
			else
			{
				print "$dump[0],$dump[1],", $dump[2], ",$dump[3],$date,$from[0],$hostname\n";
				#print "$dump[0],$dump[1],", encode( $encoding,$dump[2]), ",$dump[3],$date,$from[0],$hostname\n";
			}
		}
		else
		{
			if( $show_hidden )
			{
				print "$dump[0],$dump[1],",  $dump[2], ",$dump[3],$date,'',$hostname,$dump[7]\n";
				#print "$dump[0],$dump[1],", encode( $encoding, $dump[2]), ",$dump[3],$date,'',$hostname\n";
			}
			else
			{			
				print "$dump[0],$dump[1],",  $dump[2], ",$dump[3],$date,'',$hostname\n";
				#print "$dump[0],$dump[1],", encode( $encoding, $dump[2]), ",$dump[3],$date,'',$hostname\n";
			}
		}
	}
	elsif( $print_html )
	{
		print "
<tr>
	<td width=\"150\"><a name=\"$dump[0]\">$date</a></td>
	<td width=\"150\">$hostname</td>
	<td width=\"400\">$dump[1]</td>
	<td width=\"40\">$dump[3]</td>
	<td width=\"300\">$dump[2]</td>
	<td width=\"200\">&nbsp;
		";

		# check if we've visited from somewhere else
		if( defined @from )
		{
			print "
	From [<a href=\"#",$dump[5],"\">",$from[1],"]</a>
			";
		}
		print "</td>
</tr>
		";
	}
	else
	{
		# should not get here
		print "No output chosen, printing nothing (for each entry)\n";
	}
}


# if we are using a HTML report, close the table
if( $print_html )
{
	print "
</table>
<br />
Web page printed using $0
</body>
</html>
	";
}

if ($print_txt )
{
	print "-------------------------------------------------------\n";
}

# check to see if database is locked, then delete temp file
if( $db_lock )
{
	print STDERR "Deleting temporary history file, $db_file \n";
	unlink( $db_file );
}

# functions

#	get_url
# This function takes as an input a ID from the table moz_historyvisists and
# returns a simple array containing few of relevant information from that URL
#
# @param id	The identification number for the URL in the moz_historyvisists table
# @return	An array containing the hostname, URL and date of visit
sub get_url
{
	my $statement;
	my $s_url;
	my $s_host;
	my $s_date;
	my @return;
	
	# construct the SQL statement
	$sql = "
SELECT url,rev_host,visit_date 
FROM moz_places, moz_historyvisits
WHERE
	moz_places.id = moz_historyvisits.place_id
	AND moz_historyvisits.id = ?
	";

	$statement = $db->prepare( $sql );
	$result  = $statement->execute( $_[0] );
	
	# retrieve the results
	($s_url, $s_host, $s_date ) = $statement->fetchrow_array();

	# fix variables
	$s_host = fix_hostname( $s_host );	
	$s_date = fix_date( $s_date );
	
	# push variables to return array
	push( @return, $s_url );
	push( @return, $s_host );
	push( @return, $s_date );

	return @return;
}

#	fix_hostname
# This function takes the hostname variable, as represented in the 
# moz_places table which is in a reverse format, prepended with a dot
# and reverses it and removes the front dot (.)
#
# @params hostname A string that is of the Mozilla format for rev_host
# @return Returns a string containing the more readable version of the hostname
sub fix_hostname
{
	my $host;

	$host = reverse $_[0];
	if( $host =~ m/^\./ )
	{
		$host = substr( $host, 1, length( $host) - 1 );
	}

	return $host;
}

#	fix_date
# Since Mozilla represents date in a little different fashion than UNIX
# we need to modify it so that we can display it in a human readable format.
# The date is easily fixed, Mozilla defines the date as microseconds not seconds
# since January 1. 1970 (POSIX time), so we need to divide the time by 1000000 
# to get seconds.  Then we need to counter a possible time scew since we are 
# investigating a computer that might have the wrong time settings.
#
# @params time A formatted date variable from Mozilla
# @return The date in human readable format
sub fix_date
{
	# read the parameter
	my $s_date = $_[0];

	# check to see if the time offset variable is correctly formatted
	# this variable contains the user input of time scew from the 
	# original file
	if ( $time_offset =~ m/^-?\d+$/ )
	{  
		# divide the number
		$s_date = $s_date / 1000000 + $time_offset;
	}
	else
	{
		print STDERR  "Time offset badly formed\n";
		# offset is badly formed, just just without
		$s_date = $s_date  / 1000000;
	}

	return ctime( $s_date );
}

#	get_time
# A function to return the current time in GMT
# @return The current time in GMT
sub get_time 
{
	# for time
	my @months; 
	my @weekDays;
	my $second;
	my $minute;
	my $hour;
	my $dayOfMonth;
	my $month;
	my $yearOffset;
	my $dayOfWeek;
	my $dayOfYear;
	my $daylightSavings;
	my $year; 
	my $time;

	@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
	$year = 1900 + $yearOffset;

	$time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";

	return $time;
}

sub print_help
{
	print "
$0 version $version
Copyright Kristinn Gudjonsson 2009

Usage:
	$0 [--help|-?|-help]
		This screen

	$0 [-t TIME] [-csv|-txt|-html] [-s|--show-hidden] [-o|--only-typed] [-quiet]	places.sqlite
		-t Defines a time scew if the places.sqlite was placed on a computer with a wrong time settings.  The format of the 
			variable TIME is: X | Xs | Xm | Xh
			where X is a integer and s represents seconds, m minutes and h hours (default behaviour is seconds)
		-quiet Does not ask questions about case number and reference (default with CSV output)
		-csv|-txt|-html The output of the file.  TXT is the default behaviour and is chosen if none of the others is chosen
		-s or --show-hidden displays the \"hidden\" URLs as well as others.  These URL's represent URLs that the user
			did not specifically navigate to.
		-o or --only-typed Only show URLs that the user typed directly into the location/URL bar.
		-sort date|url|visits sorts by the access date, the url alphabetically, or the number of accesses
		-r Reverse sort order (descending)

		places.sqlite is the SQLITE database that contains the web history in Firefox 3.  It should be located at:

	[win xp] c:\\Documents and Settings\\USER\\Application Data\\Mozilla\\Firefox\\Profiles\\PROFILE\\places.sqlite
	[linux] /home/USER/.mozilla/firefox/PROFILE/places.sqlite
	[mac os x] /Users/USER/Library/Application Support/Firefox/Profiles/PROFILE/places.sqlite\n\n";
}
