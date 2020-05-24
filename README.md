podcast-archiver
================
This is a simple script to archive podcasts. It takes the URL of an RSS feed and the path of a target directory as arguments.

If an episode is already downloaded, it will not be downloaded again, unless the -f/--force flag is set.

If an episode is already present is determined by the filename. The script will decide how it _would_ name the file were it to be  downloaded, then see if that file already exists.


For each episode, two files will be created:

    [title] - [filename on server including suffix]

and

    [title].description.html
    

Usage
-----
    cd podcast-archiver
    ./cli.pl [options] rss_feed_url target_directory
    
    
Valid arguments
---------------
    --keep,    -k: Don't refresh the feed file if it has already been downloaded
    --date,    -d: Prepend the publishing date to the filename for improved sorting
    --verbose, -v: Display more information about what's happening, e.g. the exact file names being written to
    --quiet,   -q: Only display errors, you can use this when running from cron
    --dry-run, -n: Display what would happen without doing it. The RSS feed will be downloaded regardless
    --force,   -f: Force redownload of all episodes regardless if they're already downloaded. This does not override dry-run and can be used in conjunction with it.
    --help,    -h: Display this help
    [Feed URL]
    [Target directory]