#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

require "./podarchivelib.pl";

# Get the first two arguments
my($source, $target)=@ARGV;

# Where all required arguments supplied?
unless(defined($ARGV[0]) && defined($ARGV[1]))
{
    die("Not enough arguments! Both an RSS feed and a target directory are required\n");
}

unless(-d $target)
{
    die($target." is not a valid target directory!\n");
}

downloadFeed($source, $target);