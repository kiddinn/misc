#!/usr/bin/perl
######################################################################################
#		PREFETCH LAYOUT.INI READER 
######################################################################################
# A small script that reads the Layout.ini file created inside the Prefetch directory
# and prints out information from the file
#
# The script also reads the MAC time of all the files found inside the Prefetch
# directory as well as to parse the actual .PF file and gain additional information
# from it
#
# The Windows filesystem needs to be mounted prior to running this script, using
# software like NTFS-3g
#
# mount.ntfs-3g -o ro,loop,nodev,noexec,show_sys_files PATHTOIMAGE/image.dd /mnt/analyze
#
# Then the script can be run like this:
#
# read_prefetch /mnt/analyze/WINNT/Prefetch
#
# or if you prefer a HTML output
#
# read_prefetch -h /tmp/report.html /mnt/analyze/WINNT/Prefetch
#
# Changelog: added support for Vista's superfetch
#
# Author: Kristinn Gudjonsson ( kristinn ( a t ) log2timeline ( d o t ) net )
#
# Copyright 2010 Kristinn Gudjonsson, kristinn ( a t ) log2timeline( d o t ) net
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
#
# Version: 0.5
# Date : 26/01/2010
#
use strict;
use Time::localtime;
use CGI qw/:standard/;	# used to create a HTML document
use Getopt::Long; # read parameters
use Digest::MD5;	# for MD5 sums

# create variables
my $version = "0.5";
my $prefetch_dir;
my $layout;
my $date;
my @lines;
my $line;
my $offset;
my $tag;
my $i;
# to read files in the prefetch directory
my @dirs;
my $pre_file;
my $digest;	# for MD5 sum creation
# to get information about files in the prefetch directory
my $dev;
my $inode;
my $mode;
my $nlink;
my $uid;
my $gid;
my $rdev;
my $size;
my $atime;
my $mtime;
my $ctime;
my $blksize;
my $blocks;
my $print_html = 0;
my $path;
my $xp = 1;	# a variable that defines if we are examining XP prefetch files or Vista/Win 7
my $html = undef;
my $print_help = 0;
my $vista = 0;

# read options
GetOptions(
        "html=s"=>\$html,
	"xp!"=>\$xp,
	"vista!"=>\$vista,
        "help|?!"=>\$print_help
) or print_help(0);

# check for help
print_help(0) if $print_help;
exit 0 if $print_help;

if( $vista )
{
	# it implies that xp equals to 0
	$xp = 0;
}


# test parameters
sub print_help($)
{
	my $txt = shift;

	# check for existance of an error text
	print "Wrong usage: $txt\n\n" if $txt;

	print "
Usage: $0 [-h|-html FILE] [-xp|vista] DIR \nWhere DIR is the directory that contains the Prefetch directory

\tWhere -h means that the output will be in HTML instead of plain text (the name of the HTML file must be provided after -h)
\tAnd -v|-vista means that we are dealing with a Windows Vista or newer operating system (default assumes XP)
\n\tSuch as: $0 /mnt/analyse/WINNT/Prefetch\n";
}


# the directory name should now be contained in this variable
$prefetch_dir = shift;

# check if directory exists
print_help( 'The directory ' . $prefetch_dir . ' does not exist') unless -d $prefetch_dir;
exit 18 unless -d $prefetch_dir;

# and the Layout.ini file
$layout = $prefetch_dir . "/Layout.ini";


# check if the layout file exists
print_help( 'Is this really an prefetch folder, there is no Layout.ini file inside' ) unless -f $layout;
exit 15 unless -f $layout;

# start by reading the content of the directory
opendir( IMD, $prefetch_dir ) || die( "Could not open the directory $prefetch_dir\n" );
@dirs = readdir( IMD );
closedir( IMD);

# check to see if the output should be printed on screen or to a html file
if ( $print_html )
{
	# read user input, small details to put into the report (HTML report)
	print "Enter case number: ";
	my $cnr = <STDIN>;
	chomp( $cnr );

	print "Case reference: ";
	my $cref = <STDIN>;
	chomp( $cref );

	print "Investigator name: ";
	my $cinv = <STDIN>;
	chomp( $cinv );

	print HTML "
<html>
	<head><title>Prefetch File</title></head>

	<body>

        <h1 align=\"center\">Windows Prefetch Directory</h1>

<br />
This report is the output from the script $0 (version $version ) <br />
This script reads the content of the Microsoft Windows Prefetch directory and displays the MAC times of 
all files found in the directory as well as displaying the content of the file Layout.ini <br />
<br />
Case number: $cnr <br />
Case reference: $cref <br/>
Investigator: $cinv <br />
<br />
Log history: <br />
<ul>
<li>The prefetch folder is located at: $prefetch_dir</li>
<li>The script is run by the user ",`whoami`, " </li>
<li>The script is run in the folder ", `pwd`, " </li>
<li>Current date ",`date`, "</li>
</ul>
<br />
<br />
<h2 align=\"center\">Content of Prefetch directory</h2>
	<table width=\"100%\" align=\"center\" cellpadding=\"0\" cellspacing=\"0\">
	<tr> 
		<td colspan=\"5\"><hr/></td>
	</tr>
	<tr>
		<th>Name</th>
		<th>Inode</th>
		<th>Time (access)</th>
		<th>Time (modified)</th>
		<th>Time (created)</th>
	</tr>
	<tr> 
		<td colspan=\"5\"><hr/></td>
	</tr>
	";
}
else
{
	# print standard text on screen
	print "==============================================================\n";
	print "Name\t\tInode\t\tTime (access)\t\tTime (modified)\t\tTime (created)\n";
	print "--------------------------------------------------------------\n";
}

my $i;

# no we can read all the files that are included in this directory
foreach $pre_file (@dirs)
{
	# don't want to include the Layout.ini file here, read that later
	if( $pre_file ne "Layout.ini" && $pre_file ne "." && $pre_file ne ".."  )
	{
		# get information about the file
		($dev,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$prefetch_dir/$pre_file");

		if( $print_html )
		{
			printf HTML ( "<tr>\n<td>%s</td>\n<td>%s</td>\n<td>%s</td>\n<td>%s</td>\n<td>%s</td>\n</tr>\n", $pre_file,$inode,ctime($atime),ctime($mtime),ctime($ctime) );
		}
		else
		{
			printf ( "%s\t%s\t%s\t%s\t%s\n", $pre_file,$inode,ctime($atime),ctime($mtime),ctime($ctime) );
		}
	}
}

print "\n\n" unless $print_html;

# if the report is in html we need to close the table
if ( $print_html )
{
	print HTML "
	<tr> 
		<td colspan=\"5\"><hr /></td>
	</tr>
</table>
<br />
<br />
<table>
<tr>
	<th colspan=\"2\"><b>Additional informatio</b></th>
</tr>
<tr>
	<th>Field</th>
	<th>Data</th>
</tr>
	";
}

# go through all the prefetch files again, this time parsing the prefetch file to extract additional information from it
foreach $pre_file (@dirs)
{
	# don't want to include the Layout.ini file here, read that later
	if( $pre_file ne "Layout.ini" && $pre_file ne "." && $pre_file ne ".."  )
	{
		# parse the prefetch file
		$i = parse_pref_file( "$prefetch_dir/$pre_file" );
	
		# calculate the MD5 sum of the file
		$digest = Digest::MD5->new;
		open( MD5FH, "$prefetch_dir/$pre_file" );
		$digest->addfile( *MD5FH );
		close( MD5FH );

		if ( $print_html )
		{
			print HTML "<tr>\n<td align=\"right\"><b>Filename:</b></td><td>$pre_file</td></tr> 
<tr><td align=\"right\"><b>MD5SUM of file:</b></td><td>",$digest->hexdigest, "</td></tr> 
<tr><td align=\"right\"><b>Date of last execution:</b></td><td>",ctime( $i->{'timestamp'} ), "</td></tr> 
<tr><td align=\"right\"><b>Number of Executions:</b></td><td>",$i->{'nu_executions'},"</td></tr>
<tr><td align=\"right\"><b>Filepath:</b></td><td>",$i->{'filepath'},"</td></tr>";
		}
		else
		{
			print "----------------------------------------------------------------------------------\n";
			print "File: $pre_file\n";

			# fix the path name a bit for printing
			$path = $i->{'filepath'};
			$path =~ s/\n/\n\t- /g;

			print "MD5 sum of file: ",$digest->hexdigest,"\n";
			print "Date of last execution: " . ctime( $i->{'timestamp'} ) . "\n";
			print "Number of executions: " . $i->{'nu_executions'} . "\n";
			print "Volume Date of creation: " . ctime( $i->{'timestamp_volume'} ) . "\n" unless $i->{'timestamp_volume'} eq 0;
			print "Filepath: \n\t- $path\n";
			print "----------------------------------------------------------------------------------\n\n";

	#printf STDERR "OFS VOLUME: 0x%x\n",$info{'ofs_volume'};

	#printf STDERR "FROM VOLUME INFORMATION\n";
	#printf STDERR "OFS VOLUME PATH: 0x%x\n",$info{'ofs_volume_path'};
	#printf STDERR "LENGTH VOLUME PATH: 0x%x\n",$info{'length_volume_path'};
	#printf STDERR "VOLUME CREATION %i\n",$info{'timestamp_volume'};
		}
	}
}

print HTML "</table><br />" if $print_html;



# read the rp.log file
open( FILE, "$layout" ) || die("Could not open file: $layout");
# this is a binary file
binmode(FILE);

# begin at the beginning
$offset = 0;
# read the name, byte by byte
$tag = 1;
while( $tag )
{
	# go to offset of file (starts in byte 16)
	seek(FILE,$offset,0);
	# read 2 bytes, since we are reading a unicode text
	read(FILE,$i,2);
	
	# check if we have reached the end of the name part
	if( unpack( "v", $i ) == 0 )
	{
		# '00' means the end of the name
		$tag = 0;
	}
	else
	{
		# not yet at the end, let's continue and push the value into the array
		push( @lines, $i );
	}
	# increase the offset
	$offset += 2;
}
		
# now we have the entire name, let's input it into an array
$line = join('',@lines);
# and remove unnecessary information from it
$line =~ s/\00//g;

if ( $print_html )
{
	$line =~ s/\n/<br \/>/g;

	print HTML "	
	<br />
	<h2 align=\"center\">Content of Layout.ini</h2>
	<table width=\"100%\" align=\"center\" cellpadding=\"0\" cellspacing=\"0\">
	<tr> 
		<td><hr/></td>
	</tr>
	<tr>
		<th>Name</th>
	</tr>
	<tr>
		<td>$line</td>
	</tr>
	<tr> 
		<td><hr/></td>
	</tr>
	</table>
	";
}
else
{
	print "$line\n";
}
close( FILE );

if( $print_html )
{
	print "HTML report printed into file $html\n";
	close( HTML );
}

# information gathered from a blog post, https://42llc.net/index.php?option=com_myblog&show=Prefetch-Files-Revisited.html&Itemid=39
sub parse_pref_file($)
{
	my $file = shift;
	my $ofs;
	my $temp;
	my @array;

	my %info;

	# open the prefetch file	
	open( PF, $file );
	binmode(PF);

	# read the "important bits"

	# offset to block containing filepaths (DWORD)
	seek(PF,0x64,0);
	read(PF,$temp,4);
	$info{'ofs_filepath'} = unpack( "V", $temp );

	# lenght of block containing Filepaths (dword)
	seek(PF,0x68,0);
	read(PF,$temp,4);
	$info{'length_filepath'} = unpack( "V", $temp );

	# offset to volume information block
	seek(PF,0x6C,0);
	read(PF,$temp,4);
	$info{'ofs_volume'} = unpack( "V", $temp );
	
	# program last execution time
	seek(PF,0x78,0) if $xp;
	seek(PF,0x80,0) unless $xp;
	read(PF,$temp,8);
	my ($a,$b ) = unpack( "VV", $temp );

	$info{'timestamp'} = Win2Unix( $a, $b );

	# Number of Executions (DWORD)
	seek(PF,0x90,0) if $xp;
	seek(PF,0x98,0) unless $xp;
	read(PF,$temp,4);
	$info{'nu_executions'} = unpack( "V", $temp );


	# now to parse the content of the file

	# read the filepath
	@array = '';
	for( my $i = 0; $i < $info{'length_filepath'}; $i+=2 )
	{
		$ofs = $i + $info{'ofs_filepath'};
		seek(PF,$ofs,0);
		read(PF,$temp,2);

		if( unpack( "v", $temp ) == 0 ) 
		{
			$info{'filepath'} .= join( '', @array );
			$info{'filepath'} .= "\n";
			@array = '';
		}
		else
		{
			push( @array, $temp );
		}
	}
	$info{'filepath'} =~ s/\00//g;
	
	# now to read the volume information block

	# volume path offset (DWORD)
	seek(PF,$info{'ofs_volume'},0);
	read(PF,$temp,2);
	$info{'ofs_volume_path'} = unpack("V",$temp);

	# volume path length (DWORD)
	seek(PF,$info{'ofs_volume'}+0x04,0);
	read(PF,$temp,2);
	$info{'length_volume_path'} = unpack("V",$temp);

	# volume creation date (FILETIME)
	seek(PF,$info{'ofs_volume'}+0x08,0);
	read(PF,$temp,4);
	($a,$b) = unpack("VV",$temp);

	$info{'timestamp_volume'} = Win2Unix($a,$b);

	# volume serial number (DWORD)
	seek(PF,$info{'ofs_volume'}+0x10,0);
	read(PF,$temp,2);
	$info{'serial_volume'} = unpack("V",$temp);

	# offset to blob1
	seek(PF,$info{'ofs_volume'}+0x14,0);
	read(PF,$temp,2);
	$info{'ofs_blob1'} = unpack("V",$temp);

	# length of blob1
	seek(PF,$info{'ofs_volume'}+0x18,0);
	read(PF,$temp,2);
	$info{'length_blob1'} = unpack("V",$temp);
	
	# offset to folder paths
	seek(PF,$info{'ofs_volume'}+0x1C,0);
	read(PF,$temp,2);
	$info{'ofs_folder_paths'} = unpack("V",$temp);

	# number of folder paths
	seek(PF,$info{'ofs_volume'}+0x20,0);
	read(PF,$temp,2);
	$info{'nu_folder_paths'} = unpack("V",$temp);

	# read the content from the volume information block

	#printf STDERR "OFS VOLUME: 0x%x\n",$info{'ofs_volume'};
	#printf STDERR "EPOCH TIME %i\n",$info{'timestamp'};
	#printf STDERR "NUMBER OF EXECUTIONS: 0x%x\n",$info{'nu_executions'};
	#printf STDERR "FILEPATH:\n %s\n",$info{'filepath'};

	#printf STDERR "FROM VOLUME INFORMATION\n";
	#printf STDERR "OFS VOLUME PATH: 0x%x\n",$info{'ofs_volume_path'};
	#printf STDERR "LENGTH VOLUME PATH: 0x%x\n",$info{'length_volume_path'};
	#printf STDERR "VOLUME CREATION %i\n",$info{'timestamp_volume'};

	# close the file
	close(PF);

	return \%info;
}

# A subroutine copied from ptfinder.pl developed by Andreas Schuster 
# and Csaba Barta.  This sub routine converts Windows FILETIME into a 
# Unix Epoch time format
#
# n.b. FILETIME is represented in UTC
#
# Copyright (c) 2009 by Andreas Schuster and Csaba Barta
sub Win2Unix 
{
        my $Lo = shift;
        my $Hi = shift;
        my $Time;

        if ($Lo == 0 && $Hi == 0) {
                $Time = 0;
        } else {
                $Lo -= 0xd53e8000;
                $Hi -= 0x019db1de;
                $Time = int($Hi*429.4967296 + $Lo/1e7);
        };
        $Time = 0 if ($Time < 0);
        return $Time;
}

