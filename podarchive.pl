#!/usr/bin/env perl
use strict;
use warnings;

use File::Fetch; # https://perldoc.perl.org/File/Fetch.html
use File::Basename;
use File::Spec; # https://perldoc.perl.org/File/Spec.html
use XML::RSS::Parser; # https://metacpan.org/pod/XML::RSS::Parser
use FileHandle;
use DateTime::Format::RSS; # https://metacpan.org/pod/DateTime::Format::RSS

# Prevent "wide character in string" messages (some show notes contain Emojis and other UTF-8 characters)
use open qw(:std :utf8);

# For debugging
# use Data::Dumper;

use Getopt::Long; # Docs: https://perldoc.perl.org/Getopt/Long.html#Mixing-command-line-option-with-other-arguments
Getopt::Long::Configure ("bundling");

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

# Were the required arguments $source and $target supplied?
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


# =================================================================================================
# The inputs are valid, things are starting to happen

# Download the RSS feed, unless it already exists and $opt_keep is set
# If -n | --dry-run is set, download a temporary file that will be cleaned up afterwards.
my $feed_file = File::Spec->join($target, "feed.rss");
    
unless(-e $feed_file && $opt_keep)
{
    printv("Downloading feed...", 0);
    
    unless($opt_dry)
    {
        downloadFile($source, $feed_file);
    }
    else
    {
        $feed_file = downloadFile($source);
    }
    
    printv("Done\n", 0);
    printv("RSS feed saved at ".$feed_file."\n", 1);
}
else
{
    printv("Keeping preexisting feed file", 0);
    printv(" at ".$feed_file, 1);
    printv("\n", 0);
}

# Read the RSS feed from the file
# https://metacpan.org/pod/XML::RSS::Parser::Feed
my $parser = XML::RSS::Parser->new;
my $filehandle = FileHandle->new($feed_file);

# parse_file() will return false on failure.
# That means the downloaded file was not a valid RSS feed
my $feed;
unless($feed = $parser->parse_file($filehandle))
{   
    if($opt_keep)
    {
        printv("Fatal Error: Could not read RSS feed from local file \"".$feed_file."\"\n", -1);
        printv("WARNING: The -k|--keep flag is set. You may want to remove it to download the feed again.\n", -1);
    }
    else
    {
        printv("Fatal Error: Could not read RSS feed from \"".$source."\". The file was saved to \"".$feed_file."\"\n", -1);
    }
    
    exit();
}

# =================================================================================================
# At this point, the feed has been downloaded and confirmed to be a feed.
# We can start extracting its contents now.


# This should be the name of the podcast
my $name = $feed->query("title")->text_content;


# Create an HTML file (index.html) containing an overview of the archive
my $html;
unless($opt_no_overview)
{
    $html = "<html>";
    $html .= "\n<head>";
    $html .= "\n<title>".$name."</title>";
    $html .= "\n</head>";
    $html .= "\n<body>";
    $html .= "\n<h1>".$name."</h1>";
    $html .= "\n<ul>";
}
    
    
# Iterate over the feed items
#     https://metacpan.org/pod/XML::RSS::Parser::Element
my $ignorecount = 0;
my $downloadcount = 0;

# This is solved with 'for' instead of 'foreach' so the index $i doesn't need to be counted separately
# Number of all items: @feeditems
# One item: $feeditems[$i]
my @feeditems = $feed->items;
printv(@feeditems." episodes\n", 1);
for my $i (0 .. @feeditems-1)
{
    # The title of this episode
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
    # Relative paths (ending in _rel) are used for the overview
    
    # Remove special characters from the title so it can be used in the filename
    my $clean_title = clean_filename($title); 

    # The "description" is an HTML page containing both the audio file and the show notes
    my $description_path_rel = $clean_title.".html";
    my $description_path = File::Spec->join($target, $description_path_rel);

    my $audio_path_rel = $clean_title." - ".basename($url);
    my $audio_path = File::Spec->join($target, $audio_path_rel);

    # Add this episode to the overview
    unless($opt_no_overview)
    {
        $html .= "\n<li><a href=\"".$description_path_rel."\">".$title."</a></li>";
    }


    # Ignore episodes that have already been downloaded, unless $opt_force is true
    # The existence of each individual file will be checked again in case only one of them was missing.
    unless((-e $description_path && -e $audio_path) && !$opt_force)
    {
        printv($title."\n");

        # Write show notes
        unless(-e $description_path && !$opt_force)
        {
	        printv("\tWriting episode page to ".$description_path."\n",1);
	
	        unless($opt_dry)
	        {
	            my $description = "<html>";
	            $description .= "\n<head>";
	            $description .= "\n<title>".$title."</title>";
	            $description .= "\n</head>";
	            $description .= "\n<body>";
	            $description .= "\n<h1>".$title."</h1>";
	            $description .= "\n<audio controls preload=none src=\"".$audio_path_rel."\"></audio>";
	            
	            # Some podcasts use 'content:encoded', description might still be set
	            if(defined($feeditems[$i]->query('content:encoded')))
	            {
	                $description .= $feeditems[$i]->query('content:encoded')->text_content;
	            }
	            else
	            {
	                $description .= $feeditems[$i]->query('description')->text_content;
	            }
	            
	            $description .= "\n</body>";
	            $description .= "\n</html>";
	            string_to_file($description, $description_path, $opt_force);
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
    $html .= "</ul>\n</body>\n</html>";
    my $html_path = File::Spec->join($target, "index.html");
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
# $output is the target filename. If it already exists, it will be overwritten!
# If no $output path is provided, a temporary file will be written instead
sub downloadFile
{
    if(@_ < 1){die("Not enough arguments supplied to downloadFile()")}
    my ($source, $output) = @_;
    
    my $ff = File::Fetch->new(uri => $source) or die("Invalid URL ".$source);
    
    if($output)
    {
        my $output_dir = dirname($output);
        
        # The file will be downloaded to $output_dir, then renamed to $output
        my $temp = $ff->fetch(to=>$output_dir) or die("Failed to download ".$source);
        rename($temp, $output) or die("Failed to rename downloaded file: ".$!."\n");
    }
    else
    {
        my $scalar;
        my $temp = $ff->fetch(to => \$scalar) or die("Failed to download ".$source);
    }
}

# Write a given string to a new file. Existing files will only be overwritten if the 3rd argument is true.
# Maybe should've used: https://learn.perl.org/examples/read_write_file.html
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

# Replace everything with a dash (-) that is not a letter, number, dash, dot or space, so the given string can be used as a filename
# Help with RegEx: https://perldoc.perl.org/perlre.html
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
        
        # This expression will match dashes with whitespace behind, but not in front of them: abc- abc
        # (?<!\s) = negative lookbehind (matches if the dash is NOT preceded by whitespace)
        $filename =~ s/(?<!\s)-\s/ - /g;
        
        # This expression will match dashes that with whitespace in front of, but not behind them: abc -abc
        # (?!\s) = negative lookahead (matches if the dash is NOT succeeded by whitespace)(
        $filename =~ s/\s-(?!\s)/ - /g;
        
        return($filename);
    }
}
