podarchive
==========
This is a simple script for archiving podcasts, including show notes.

I made this because I wanted to download and archive some podcasts I like, but wasn't satisfied with the solutions that already exist. None of them seemed to save the show notes or let me customize the names of the downloaded files to my liking, so I made `podarchive` to solve that.

Behaviour
---------
The script takes the URL of an RSS feed and a (local) target directory as arguments. The feed will be downloaded to the specified directory (as `feed.rss`) and then used to download the episodes. Audio files are downloaded and not altered, only renamed. For each episode, an HTML file will be created. It embeds the audio file and also contains the show notes.

The filename is used to determine if an episode has already been downloaded. Episodes will not be downloaded again, unless the `-f|--force` flag is set. The script will decide how it would name the file, then see if that file already exists. That means it will not recognize episodes that were downloaded with different settings (like `-d|--date` or `-e|--episode-number`).

`podarchive` will also create an `index.html` file containing a list of all episodes, as well as links to their individual HTML files. This can be disabled using the `--no-overview` flag. Any `index.html` that already exists in the target directory will be overwritten.

Usage
-----
    [perl] ./podarchive.pl [options] rss_feed_url target_directory

    
### Options
You can try them out by using the `-n|--dry-run` flag

    --date,           -d  Prepend the publishing date to the filename for improved sorting.
                          This is useful for all podcasts that don't neatly include the
                          number in every episode's title.
    
    --episode-number, -e  Prepend the episode number to the title for improved sorting. This
                          is less reliable than using the publishing date, but will look a lot
                          cleaner if successful. If -e and -d are used in conjunction, the
                          date will be placed in front of the number.
                          
    --date-behind         Append instead of prepend the date. Implies -d.
    
    --no-overview         Don't create an index.html file containing an overview of all episodes.
    
    --verbose,        -v  Display more information about what's happening, e.g. the exact file
                          names being written to.
    
    --quiet,          -q  Only display errors. Use this when running from cron.
    
    --dry-run,        -n  Display what would happen without doing it. The RSS feed will be
                          downloaded regardless.
    
    --keep,           -k  Don't refresh the feed file if it has already been downloaded
    
    --force,          -f  Force re-downloading of all episodes regardless of wether they've already
                          been downloaded. This does not override -n | --dry-run and can be used in
                          conjunction with it.
    
    --help,           -h  Display this help

### Compatible Podcasts
`podarchive` should work with all podcasts using the standard RSS format.

These are some podcasts I have tried and confirmed to work:

* Hello Internet: http://www.hellointernet.fm/podcast?format=rss
* Accidental Tech Podcast: https://atp.fm/rss
* The Unmade Podcast: https://www.unmade.fm/episodes?format=rss

Operating Systems
-----------------
`podarchive` has been extensively tested on both macOS and FreeBSD, but it also works on Linux.

It seemed to work during my short tests in Windows 7 and 10 VMs.

Dependencies
------------
Please refer to the `use` calls at the beginning of `podarchive.pl` for the used modules. I'm not putting a list here because im 100% sure I would forget updating it. You can also just try to run it, Perl should give you an error message about missing modules.

Compiled Binaries
-----------------
The `make.sh` (UNIX) and `make.bat` (Windows) scripts use [`pp`](https://metacpan.org/pod/pp) to create an executable binary file (`podarchive` on UNIX, `podarchive.exe` on Windows), which should then be able to run without having the dependencies installed. However, making the binary still requires the dependencies, so this is only useful if multiple computers **running the same operating system** are involved.

This whole process is not tested very well, that's why I'm not publishing binaries.

How I'm using it
----------------
`podcarchive` runs in a daily cronjob on my FreeBSD NAS. While Perl itself is installed, the required modules are not, so I am using a binary file created with `make.sh`.
