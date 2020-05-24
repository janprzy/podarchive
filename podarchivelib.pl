#!/usr/bin/perl
use File::Fetch; # https://perldoc.perl.org/File/Fetch.html
use File::Copy;
use File::Basename;
use XML::RSS::Parser; # https://metacpan.org/pod/XML::RSS::Parser
use Filehandle;

# $source is a URI to the podcast's rss feed
# $target is the directory it should be saved to
sub downloadFeed
{
    if(@_ < 2) {die("Not enough arguments supplied to downloadFeed()")}
    my ($source, $target) = @_;    
    
    my $feed_file = $target."/feed.rss";
    
    # Don't download again if it already exists (just for debugging, a real feed would obviously be updated regularly
    unless(-e $feed_file)
    {
        downloadFile($source, $feed_file);
    }
    
    my $parser = XML::RSS::Parser->new;
    my $filehandle = FileHandle->new($feed_file);
    my $feed = $parser->parse_file($filehandle); # https://metacpan.org/pod/XML::RSS::Parser::Feed
    
    # Iterate over the items
    my $ignored;
    foreach my $item ($feed->items) # https://metacpan.org/pod/XML::RSS::Parser::Element
    {
        # Get important data from the item
        my $title = $item->query('title')->text_content;
        my $date  = $item->query('pubDate')->text_content;
        my $url   = $item->query('enclosure')->attribute_by_qname("url");
        my $description = $item->query('description')->text_content;
        
        # Target paths for this episode
        my $description_path = $target."/".$title.".description.html";
        my $audio_path = $target."/".$title." - ".basename($url);
        
        # Ignore episodes that have already been downloaded
        # The existence of each individual file will be checked again in case only one of them was missing.
        unless(-e $description_path && -e $audio_path)
        {
            print($title.", published on ".$date."\n");
        
            # Write show notes
            unless(-e $description_path)
            {
                print("\tWriting show notes to ".$description_path."\n");
                string_to_file($description, $description_path);
            }
            else
            {
                print("Show notes already exist at ".$description_path);
            }
        
            # Download Audio file
            unless(-e $audio_path)
            {
                print("\tDownloading ".$url." to ".$audio_path."\n");
                downloadFile($url, $audio_path);
            }
            else
            {
                print("Audio already exists at ".$audio_path);
            }
        }
        else
        {
            $ignorecount++;
        }
    }
    
    print("Ignored ".$ignorecount." items that have already been downloaded.\n");
}

# Download a file
# Output is the target filename
sub downloadFile
{
    if(@_ < 2){die("Not enough arguments supplied to fetchFile()")}
    my ($source, $output) = @_;
    
    if(-e $output){die("Could not download ".$source." to ".$output.", it already exists.")}
    
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
    if(@_ < 2) {die("Not enough arguments supplied to string_to_file()")}
    my ($string, $file) = @_;
    
    # Die if the $file already exists, this function will not overwrite.
    if(-e $file){ die("Could not write to ".$file.", it alredy exists!") }
    
    # The target directory needs to exist
    unless(-d dirname($file)){ die("Could not create ".$file.", no valid directory was provieded.") }
    
    open (FILE, "> ".$file) or die("Failed to open file for writing: ".$!);
    print FILE $string;
    close(FILE);
    
}
1;