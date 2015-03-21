#!/usr/bin/perl
######################################################################################
#		RESTORE POINT LOG READER (rp.log)
######################################################################################
# A small script that reads the rp.log file created during restore point creation
# and prints out information from the file
#
# Uses some methods developed by Harlan Carvey
#
# Author: Kristinn Gudjonsson ( kristinn ( a t ) log2timeline ( d o t ) net )
#
# Copyright 2009 Kristinn Gudjonsson, kristinn ( a t ) log2timeline ( d o t ) net
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
# Version: 0.2
# Date : 23/06/2009
use strict;
use Getopt::Std; # read parameters
use Fcntl ':mode'; # for permission reading

# create variables
my $rp_dir;
my $path_dir;
my @dirs;
my $date;
my $name;
my $timeline = 0;
my $host = '';
my $legacy = 0;
my %options;
# for file information
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

# test parameters
if( $#ARGV <  0 )
{
	print "Wrong usage: $0 [-t] [-h HOST] [-l]  DIR \nWhere DIR is the directory that contains the restore points\n";
	print "Such as: $0 /mnt/analyse/System\\ Volume\\ Information/_restore....\n";
	print "Optional: use -t to get the output in a timeline format\n";
	print "Optional: use -h HOST to include a host name in a timeline format\n";
	print "Optional: use -l to create a legacy timeline as indicated by TSK 1.X and 2.X, otherwise\n";
	print "version 3.0+ is assumed\n";
	exit 20;
}

%options=();
getopts( "th:l", \%options );

if( defined $options{t} )
{
	$timeline = 1;
}
if( defined $options{l} )
{
	$legacy = 1;
}
if( defined $options{h} )
{
	$host = $options{h};
}

# assign the parameter to the directory name
$path_dir = $ARGV[0];

# open the directory and read the content
opendir( IMD, $path_dir ) || die( "Could not open the directory $path_dir\n" );
@dirs = readdir( IMD );
closedir( IMD);

if ( $timeline == 0 )
{
	print "================================================================\n";
	print "RP\tName\t\t\t\tDate\n";
	print "----------------------------------------------------------------\n";
}
# get the correct order on the restore points
@dirs = sort( @dirs );

# read each directory 
foreach $rp_dir (@dirs)
{
	# check if this is a restore point
	if ( substr( $rp_dir, 0, 2) eq "RP" )
	{
		# then we have a restore point to work with
		($name, $date ) = read_rpfile( "$path_dir/$rp_dir" );

		if ( $timeline == 0 )
		{		
			print "$rp_dir\t$name\t\t" . gmtime($date) . "\n";
		}
		else
		{
			# now we are printing in a timeline format
			# the format is
			# (legacy)
			# time | source | host | user | description 
			# (new)
			# MD5|name|inode|mode_as_string|UID|GID|size|atime|mtime|ctime|crtime

			# print using timeline format
			if( $legacy == 1 )
			{
				print "$date|RP|$host|OS|Restore Point Created ($rp_dir) - $name\n";
			}
			else
			{
				# find information about file
				($dev,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$path_dir/$rp_dir");
				my $u;
				my $g;
				my $a;
				$u = ($mode & S_IRWXU) >> 6;
				$g = ($mode & S_IRWXG) >> 3;
				$a = $mode & S_IRWXO;

				if( $host eq '' )
				{
					print "0|Restore Point ($rp_dir) - $name|$inode|$mode|$uid|$gid|$size|$atime|$mtime|$ctime|$date\n";
				}
				else
				{
					print "0|<$host> Restore Point ($rp_dir) - $name|$inode|$mode|$uid|$gid|$size|$atime|$mtime|$ctime|$date\n";
				}
			}
		}
	}
}

if ( $timeline == 0 )
{
	print "----------------------------------------------------------------\n";
}

# -------------------- functions ----------------------


#	read_rpfile
#
# This function reads a rp (restore point) file and displays the
# name of the restore point as well as the date of creation
#
# @params	rp.log
# @return	array containing the name and date of restore point
sub read_rpfile()
{
	# define variables needed
	my $rp_file, $rp_dir;
	my @name;
	my $nafn;
	my $i;	# a buffer
	my $offset;
	my $tag;
	my @dates;
	my $date;
	my @return;
	
	# the directory is the first argument
	$rp_dir = $_[0];
	# and then we have a rp.log file underneath
	$rp_file = "$rp_dir/rp.log";

	# read the rp.log file
	open( FILE, "$rp_file" ) || return("Could not read rp.log file", "0000000");
	#open( FILE, "$rp_file" ) || die("Could not open file: $rp_file");
	# this is a binary file
	binmode(FILE);

	# read the name, starts in byte 16
	$offset = 0x10;
	
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
			push( @name, $i );
		}
		# increase the offset
		$offset += 2;
	}
	
	# now we have the entire name, let's input it into an array
	$nafn = join('',@name);
	# and remove unnecessary information from it
	$nafn =~ s/\00//g;

	push( @return, $nafn );

	# read the date value
	seek(FILE,-0x8,2);
	read(FILE,$i,8);
	
	# correct format	
	@dates = unpack("VV",$i);
	# find the actual date, using Harlan Carvey's method
	$date = getTime($dates[0],$dates[1]);
	# close the file
	close( FILE );
	
	push( @return, $date );
	
	# and now we are ready to return the values found 
	return @return;
}
	
	
# borrowed from Harlan Carvey
# This function originally came from the rip.pl script that
# is part of the RegRipper that H. Carvey published in 2008,
# this particular function was found in the version 20080419
#-------------------------------------------------------------
# getTime()
# Translate FILETIME object (2 DWORDS) to Unix time, to be passed
# to gmtime() or localtime()
#-------------------------------------------------------------
sub getTime() 
{
	my $lo = shift;
	my $hi = shift;
	my $t;
	if ($lo == 0 && $hi == 0) {
		$t = 0;
	} else {
		$lo -= 0xd53e8000;
		$hi -= 0x019db1de;
		$t = int($hi*429.4967296 + $lo/1e7);
	};
	$t = 0 if ($t < 0);
	return $t;
}

