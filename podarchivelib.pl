#!/usr/bin/perl
use File::Fetch; # https://perldoc.perl.org/File/Fetch.html
use File::Copy;
use File::Basename;
use XML::RSS::Parser; # https://metacpan.org/pod/XML::RSS::Parser
use Filehandle;
use Time::Piece;

# Prevent "wide character in string" messages (some show notes contain Emojis and other UTF-8 characters)
use open qw(:std :utf8);

# $source is a URI to the podcast's rss feed
# $target is the directory it should be saved to
sub downloadFeed
{
    if(@_ < 2) {die("Not enough arguments supplied to downloadFeed()")}
    my ($source, $target) = @_;    
    
    # Download the RSS feed
    # TODO: Don't save if --dry-run is enabled
    my $feed_file = $target."/feed.rss";
    unless($opt_keep && -e $feed_file)
    {
        downloadFile($source, $feed_file);
    }
    else
    {
        printv("Keeping preexisting feed file\n");
    }
    
    my $parser = XML::RSS::Parser->new;
    my $filehandle = FileHandle->new($feed_file);
    my $feed = $parser->parse_file($filehandle); # https://metacpan.org/pod/XML::RSS::Parser::Feed
    
    # Iterate over the items
    my $ignoredcount, $downloadcount;
    foreach ($feed->items) # https://metacpan.org/pod/XML::RSS::Parser::Element
    {
        # Get important data from the item
        my $title = $_->query('title')->text_content;
        my $date  = $_->query('pubDate')->text_content;
        # Change date format to ISO8601 - https://metacpan.org/pod/release/MSERGEANT/Time-Piece-1.20/Piece.pm
        #$date = Time::Piece->strptime($date, )->strftime("%Y%m%d");
        
        my $url   = $_->query('enclosure')->attribute_by_qname("url"); # The audio file to be downloaded
        my $description = $_->query('description')->text_content;
        
        # Target paths for this episode
        my $description_path = $target."/".$title.".description.html";
        my $audio_path = $target."/".$title." - ".basename($url);
        
        # Ignore episodes that have already been downloaded
        # The existence of each individual file will be checked again in case only one of them was missing.
        unless(-e $description_path && -e $audio_path)
        {
            printv($title.", published on ".$date."\n");
        
            # Write show notes
            unless(-e $description_path)
            {
                printv("\tWriting show notes to ".$description_path."\n",1);
                unless($opt_dry){string_to_file($description, $description_path)}
            }
            else
            {
                printv("Show notes already exist at ".$description_path);
            }
        
            # Download Audio file
            unless(-e $audio_path)
            {
                printv("\tDownloading ".$url." to ".$audio_path."\n",1);
                unless($opt_dry){downloadFile($url, $audio_path)}
            }
            else
            {
                printv("Audio already exists at ".$audio_path);
            }
            
            $downloadcount++;
        }
        else
        {
            $ignorecount++;
        }
    }
    
    # Print stats
    printv("Downloaded ".$downloadcount." new episodes\n");
    if($ignorecount>0)
    {
        printv("Ignored ".$ignorecount." items that have already been downloaded.\n");
    }
}

# Download a file
# $output is the target filename
sub downloadFile
{
    if(@_ < 2){die("Not enough arguments supplied to fetchFile()")}
    my ($source, $output) = @_;
    
    # Die if file already exists, this function will not overwrite
    # if(-e $output){die("Could not download ".$source." to ".$output.", it already exists.")}
    
    my $output_dir = dirname($output);
    
    my $ff = File::Fetch->new(uri => $source);

    # The file will be downloaded to $output_dir, then renamed to $output
    my $temp = $ff->fetch(to=>$output_dir) or die($ff->error);
    move($temp, $output) or die("Failed to rename downloaded file: ".$!."\n");
}

# Write a given string to a new file. Existing files will not be overwritten.
# Should have used: https://learn.perl.org/examples/read_write_file.html
sub string_to_file
{
    if(@_ < 2){die("Not enough arguments supplied to string_to_file()")}
    my ($string, $file) = @_;
    
    # Die if the $file already exists, this function will not overwrite.
    if(-e $file){die("Could not write to ".$file.", it alredy exists!") }
    
    # The target directory needs to exist
    unless(-d dirname($file)){ die("Could not create ".$file.", no valid directory was provided.") }
    
    open(FILE, "> ".$file) or die("Failed to open file for writing: ".$!);
    print(FILE $string);
    close(FILE);
}
1;