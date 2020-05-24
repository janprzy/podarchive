#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

use Getopt::Long; # Docs: https://perldoc.perl.org/Getopt/Long.html#Mixing-command-line-option-with-other-arguments
Getopt::Long::Configure ("bundling");

require "./podarchivelib.pl";

# Command line options
our($opt_keep, $opt_date, $opt_verbose, $opt_quiet, $opt_dry, $opt_force, $opt_help);
GetOptions('keep|k' => \$opt_keep,
           'date|d' => \$opt_date,
           'verbose|v' => \$opt_verbose,
           'quiet|q' => \$opt_quiet,
           'dry-run|n' => \$opt_dry,
           'force|f' => \$opt_force,
           'help|h' => \$opt_help,
           );

if($opt_help)
{
    print_help();
    exit;
}

my($source, $target)=@ARGV;

# Where $source and $target required arguments supplied?
unless($source && $target)
{
    die("Not enough arguments! Both an RSS feed and a target directory are required\n");
}

# TODO: Create directory if it doesn't exist, only fail if the parent directory is also missing
unless(-d $target)
{
    die($target." is not a valid target directory!\n");
}

downloadFeed($source, $target);

sub print_help
{
    print("Command usage:
--keep,    -k: Don't refresh the feed file if it has already been downloaded
--date,    -d: Prepend the publishing date to the filename for improved sorting
--verbose, -v: Display more information about what's happening
--quiet,   -q: Only display errors
--dry-run, -n: Display what would happen without doing it. The RSS feed will be downloaded regardless
--force,   -f: Force redownload of all episodes regardless if they're already downloaded
--help,    -h: Display this help
[Feed URL]
[Target directory]
");
}

# Print with 3 different verbosities
# -1 - Print even if the "quiet"-option is set
#  0 - normal
#  1 - Print only if the "verbose"-option is set
sub printv
{
    if(@_ < 1){die("Not enough arguments supplied to printv()")}
    my($string, $level) = @_;
    
    unless(defined($level)){$level = 0;}
    
    if($opt_verbose || $level<=0 && !$opt_quiet || $level<=-1 && $opt_quiet)
    {
        print($string);
    }
}
