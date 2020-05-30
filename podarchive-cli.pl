#!/usr/bin/env perl
use strict;
use warnings;

use File::Fetch; # https://perldoc.perl.org/File/Fetch.html
use File::Basename;
use XML::RSS::Parser; # https://metacpan.org/pod/XML::RSS::Parser
use FileHandle;
use DateTime::Format::RSS;

# Prevent "wide character in string" messages (some show notes contain Emojis and other UTF-8 characters)
use open qw(:std :utf8);

# For debugging
# use Data::Dumper;

use Getopt::Long; # Docs: https://perldoc.perl.org/Getopt/Long.html#Mixing-command-line-option-with-other-arguments
Getopt::Long::Configure ("bundling");

# Get the parent directory of this file.
# This will allow us to run it from anywhere, it will still be able to include other files in this directory
# https://perldoc.perl.org/FindBin.html
#use FindBin qw($Bin);

#require $Bin."/podarchivelib.pl";

# Command line options
our($opt_keep, $opt_date, $opt_date_behind, $opt_no_overview, $opt_enum, $opt_verbose, $opt_quiet, $opt_dry, $opt_force, $opt_help);
GetOptions('keep|k' => \$opt_keep,
           'date|d' => \$opt_date,
           'episode-number|e' => \$opt_enum,
           'date-behind' => \$opt_date_behind,
           'no-overview' => \$opt_no_overview,
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


# === Some options imply other options ============================================================
if($opt_date_behind){$opt_date = 1}

# This allows us to only check for $opt_no_overview, there's no or-condition needed.
if($opt_dry){$opt_no_overview = 1} 
# =================================================================================================

my($source, $target)=@ARGV;

# Where $source and $target required arguments supplied?
unless($source && $target)
{
    print("Not enough arguments! Both an RSS feed and a target directory are required\n");
    print_help();
    exit;
}

# TODO: Create directory if it doesn't exist, only fail if the parent directory is also missing
unless(-d $target)
{
    die($target." is not a valid target directory!\n");
}


# === Most of the logic ===========================================================================

# Download the RSS feed,
# Unless it already exists and $opt_keep is set
# TODO: Don't save if --dry-run is enabled
my $feed_file = $target."/feed.rss";
unless(-e $feed_file && $opt_keep)
{
    printv("Downloading feed...");
    downloadFile($source, $feed_file);
        printv("Done\n");
}
else
{
    printv("Keeping preexisting feed file\n",1);
}

# Create an HTML file containing an overview of the archive
my $html;
unless($opt_no_overview)
{
    $html = "<html>";
    $html .= "\n<body>";
    $html .= "\n<head>";
    $html .= "\n<title>Podcast overview</title>";
    $html .= "\n</head>";
}

# Read the RSS feed from the file
# https://metacpan.org/pod/XML::RSS::Parser::Feed
my $parser = XML::RSS::Parser->new;
my $filehandle = FileHandle->new($feed_file);

# Exit if the URL does not contain a valid feed.
my $feed;
unless($feed = $parser->parse_file($filehandle))
{   
    if($opt_keep)
    {
        printv("Fatal Error: Could not read RSS feed from local file \"".$feed_file."\"\n", -1);
        printv("WARNING: The -k | --keep flag is set. You may want to remove it to re-download the RSS feed.\n", -1);
    }
    else
    {
        printv("Fatal Error: Could not read RSS feed from \"".$source."\". The file was saved to \"".$feed_file."\"\n", -1);
    }
    
    exit();
}
    
# Iterate over the feed items
#     https://metacpan.org/pod/XML::RSS::Parser::Element
my $ignorecount = 0;
my $downloadcount = 0;

# All items in the feed
# This is solved with 'for' instead of 'foreach' so the index $i doesn't need to be counted separately
# Number of all items: @feeditems
# One item: $feeditems[$i]
my @feeditems = $feed->items;
printv(@feeditems." episodes\n", 1);
for my $i (0 .. @feeditems-1)
{
    # Get important data from the item
    my $title = $feeditems[$i]->query('title')->text_content;

    # Prepend the publishing date to the title and the filename
    if($opt_date)
    {
        my $date  = $feeditems[$i]->query('pubDate')->text_content;
    
        # Change date format to ISO8601 - https://metacpan.org/pod/release/MSERGEANT/Time-Piece-1.20/Piece.pm
        $date = DateTime::Format::RSS->parse_datetime($date)->ymd;

        unless($opt_date_behind)
        {
	        $title = $date." - ".$title;
        }
        else
        {
	        $title = $title." - ".$date;
        }
    }

    # Prepend the episode number to the title. The typical feed will be ordered newest-to-oldest
    if($opt_enum)
    {
        $title = (@feeditems - $i)." - ".$title;
    }

    my $url   = $feeditems[$i]->query('enclosure')->attribute_by_qname("url"); # The audio file to be downloaded

    # Target paths for this episode
    # Relative paths are needed for index.html
    my $clean_title = clean_filename($title);

    my $description_path_rel = $clean_title.".description.html";
    my $description_path = $target."/".$description_path_rel;

    my $audio_path_rel = $clean_title." - ".basename($url);
    my $audio_path = $target."/".$audio_path_rel;

    # Add this episode to the overview
    unless($opt_no_overview)
    {
        $html .= "\n<hr>";
        $html .= "\n<h2>".$title."</h2>";
        $html .= "\n<a href=\"".$description_path_rel."\">Show notes</a><br>";
        $html .= "\n<audio controls preload=none src=\"".$audio_path_rel."\"></audio>";
    }


    # Ignore episodes that have already been downloaded, unless $opt_force is true
    # The existence of each individual file will be checked again in case only one of them was missing.
    unless((-e $description_path && -e $audio_path) && !$opt_force)
    {
        printv($title."\n");

        # Write show notes
        unless(-e $description_path && !$opt_force)
        {
	        printv("\tWriting show notes to ".$description_path."\n",1);
	
	        unless($opt_dry)
	        {
	            my $description = "<html>";
	            $description .= "\n<head>";
	            $description .= "\n<title>".$title."</title>";
	            $description .= "\n</head>";
	            $description .= "\n<body>";
	            $description .= $feeditems[$i]->query('description')->text_content;
	            $description .= "\n</body>";
	            $description .= "\n</html>";
	            string_to_file($description, $description_path);
	        }
        }
        else
        {
	        printv("Show notes already exist at ".$description_path."\n");
        }

        # Download Audio file
        unless(-e $audio_path && !$opt_force)
        {
	        printv("\tDownloading ".$url." to ".$audio_path."\n",1);
	        downloadFile($url, $audio_path)
	            unless($opt_dry);
        }
        else
        {
	        printv("Audio already exists at ".$audio_path."\n");
        }
    
        $downloadcount++;
    }
    else
    {
        # Display ignored episodes in verbose mode
        printv("Ignoring: ".$title."\n",1);
        $ignorecount++;
    }
}

# Finish writing index.html
# This will overwrite any existing index.html
unless($opt_no_overview)
{
    $html .= "</body>\n</html>";
    my $html_path = $target."/index.html";
    string_to_file($html, $html_path, 1);
    printv("Wrote overview to ".$html_path."\n",1);
}

# Print stats
printv("Downloaded ".$downloadcount." new episodes\n")
    if($downloadcount > 0);

printv("Ignored ".$ignorecount." episodes\n")
    if($ignorecount > 0);

# =================================================================================================

# Print with 3 different verbosities
# -1 - Print even if the "quiet"-option is set
#  0 - normal
#  1 - Print only if the "verbose"-option is set
sub printv
{
    if(@_ < 1){die("Not enough arguments supplied to printv()")}
    my($string, $level) = @_;
    
    unless(defined($level)){$level = 0;}
    
    if($opt_verbose || $level==0 && !$opt_quiet)
    {
        print($string);
    }
    elsif($level<0)
    {
        print(STDERR $string);
    }
}

sub print_help
{
    print("Command usage:
--keep,           -k: Don't refresh the feed file if it has already been downloaded
--date,           -d: Add the publishing date to the filename for improved sorting
--episode-number, -e: Prepend the episode number to the title for improved sorting
--date-behind       : Append instead of prepend the date. Implies -d.
--no-overview       : Don't create an index.html file containing an overview of all episodes
--verbose,        -v: Display more information about what's happening
--quiet,          -q: Only display errors
--dry-run,        -n: Display what would happen without doing it. The RSS feed will be downloaded regardless
--force,          -f: Force redownload of all episodes regardless if they're already downloaded
--help,           -h: Display this help
[Feed URL]
[Target directory]
");
}

# Download a file
# $output is the target filename
sub downloadFile
{
    if(@_ < 2){die("Not enough arguments supplied to downloadFile()")}
    my ($source, $output) = @_;
    
    # Die if file already exists, this function will not overwrite
    # if(-e $output){die("Could not download ".$source." to ".$output.", it already exists.")}
    
    my $output_dir = dirname($output);
    
    my $ff = File::Fetch->new(uri => $source) or die("Invalid URL ".$source);

    # The file will be downloaded to $output_dir, then renamed to $output
    my $temp = $ff->fetch(to=>$output_dir) or die($ff->error);
    rename($temp, $output) or die("Failed to rename downloaded file: ".$!."\n");
}

# Write a given string to a new file. Existing files will not be overwritten.
# Should have used: https://learn.perl.org/examples/read_write_file.html
sub string_to_file
{
    if(@_ < 2){die("Not enough arguments supplied to string_to_file()")}
    my ($string, $file, $overwrite) = @_;
    
    # Some validations
    # If the $overwrite flag is false or unset, this function will fail if the file already exists
    if(-d $file){die("Could not write to ".$file.", is a directory!")}
    if(-e $file && !$overwrite){die("Could not write to ".$file.", it already exists!")}
    
    # The target directory needs to exist
    unless(-d dirname($file)){ die("Could not create ".$file.", no valid directory was provided.") }
    
    open(FILE, "> ".$file) or die("Failed to open file for writing: ".$!);
    print(FILE $string);
    close(FILE);
}

# Replace everything with a dash (-) that is not a letter, number, dash, dot or space,
# so the given string can be used as a filename
# https://perldoc.perl.org/perlre.html
sub clean_filename
{
    my $filename = shift; # Get the first argument
    
    if(defined($filename))
    {
        # Replace everything with a dash (-) that is not a letter, number, dash, dot or space
        $filename =~ s/[^A-Za-z0-9\-\.\s]/-/g;
        
        # If a dash has whitespace on ONE side, put one space on both sides of that dash
        # This occurs, for example, when the original string contained a number followed by a colon
        # Example: abc 1- abc -> abc 1 - abc
        # Do NOT match abc - abc
        # (?<!\s) = negative lookbehind (matches if the dash is NOT preceded by whitespace)
        $filename =~ s/(?<!\s)-\s/ - /g;
        
        # (?!\s) = negative lookahead (matches if the dash is NOT succeeded by whitespace)(
        $filename =~ s/\s-(?!\s)/ - /g;
        
        return($filename);
    }
}
