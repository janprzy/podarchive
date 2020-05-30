podarchive
==========
This is a simple script for archiving podcasts, including show notes. It takes the URL of an RSS feed and the path of a target directory as arguments.

If an episode is already downloaded, it will not be downloaded again, unless the `-f|--force` flag is set.
The filename will be used to determine if an episode is already present. The script will decide how it would name the file were it to be downloaded, then see if that file already exists.

There are no config files, everything is handled via command line arguments.

An index.html file will be created in the target directory. This file contains an overview of all audio files, as well as links to the show notes. Any index.html file that already exists will be overwritten.

For each episode, two files will be created:

    [date if -d|--date flag is set] - [title] - [filename on server including suffix]

and

    [title].description.html
    

Usage
-----
    podarchive-cli.pl [options] rss_feed_url target_directory

For help type cli.pl -h
    
Options
-------
You can try them out by using the -n|--dry-run flag

    --keep,           -k: Don't refresh the feed file if it has already been downloaded
    --date,           -d: Prepend the publishing date to the filename for improved sorting. This would be useful for all podcasts that dont't neatly include the number in every episode's title
    --episode-number, -e: Prepend the episode number to the title for improved sorting. This is less reliable than using the publishing date, but will look a lot cleaner if successful. If -e and -d are used in conjunction, the number will be placed in front of the date
    --date-behind:        Append instead of prepend the date. Implies -d.
    --no-overview         Don't create an index.html file containing an overview of all episodes
    --verbose,        -v: Display more information about what's happening, e.g. the exact file names being written to
    --quiet,          -q: Only display errors, you can use this when running from cron
    --dry-run,        -n: Display what would happen without doing it. The RSS feed will be downloaded regardless
    --force,          -f: Force redownload of all episodes regardless if they're already downloaded. This does not override dry-run and can be used in conjunction with it.
    --help,           -h: Display this help
    [Feed URL]
    [Target directory]

Operating Systems
-----------------
`podarchive` has been extensively tested on both macOS and FreeBSD, but it should also work on Linux.

It has not been tested on Windows yet. There's some UNIX-specific stuff being used, most notably the forward slash ( / ) path separator, but supporting Windows is definitely on the roadmap.

Compiled Binaries
-----------------
Running the Perl script directly requires some dependencies.

The `make.sh` script uses [`pp`](https://metacpan.org/pod/pp) to create an independent binary file, which can then be run without having the dependencies installed. Since this still requires a lot of testing, I am not publishing binaries yet.

How I'm using it
----------------
`podcarchive` runs in a daily cronjob on my FreeBSD NAS. While Perl itself is installed, the required modules are not, so I am using a binary file created with `make.sh`.
