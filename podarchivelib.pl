#!/usr/bin/perl
use File::Fetch; # https://perldoc.perl.org/File/Fetch.html
use File::Basename;
use XML::RSS::Parser; # https://metacpan.org/pod/XML::RSS::Parser
use Filehandle;
use DateTime::Format::RSS;

# Prevent "wide character in string" messages (some show notes contain Emojis and other UTF-8 characters)
use open qw(:std :utf8);

# This function contains most of the logic
# $source is a URI to the podcast's rss feed
# $target is the directory it should be saved to
sub downloadFeed
{
    if(@_ < 2){die("Not enough arguments supplied to downloadFeed()")}
    my ($source, $target) = @_;    
    
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
    
    # Create an HTML file for improved viewing of the archive
    my $html = "
    <html>
        <body>";
    
    # Read the RSS feed from the file
    # https://metacpan.org/pod/XML::RSS::Parser::Feed
    my $parser = XML::RSS::Parser->new;
    my $filehandle = FileHandle->new($feed_file);
    my $feed = $parser->parse_file($filehandle);
    
    # Iterate over the feed items
    #     https://metacpan.org/pod/XML::RSS::Parser::Element
    my $ignoredcount, $downloadcount;
    
    # All items in the feed
    # This is solved with 'for' instead of 'foreach' so the index $i doesn't need to be counted separately
    # Number of all items: @feeditems
    # One item: $feeditems[$i]
    my @feeditems = $feed->items;
    foreach my $i (0 .. @feeditems-1)
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
        my $clean_title = clean_filename($title);
        
        my $description_path_rel = $clean_title.".description.html";
        my $description_path = $target."/".$description_path_rel;
        
        my $audio_path_rel = $clean_title." - ".basename($url);
        my $audio_path = $target."/".$audio_path_rel;
        
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
    
    # Print stats
    printv("Downloaded ".$downloadcount." new episodes\n")
        if($downloadcount > 0);
    
    printv("Ignored ".$ignorecount." episodes\n")
        if($ignorecount > 0);
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
    
    my $ff = File::Fetch->new(uri => $source);

    # The file will be downloaded to $output_dir, then renamed to $output
    my $temp = $ff->fetch(to=>$output_dir) or die($ff->error);
    rename($temp, $output) or die("Failed to rename downloaded file: ".$!."\n");
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


1;