podarchive
==========
This is a simple script for archiving podcasts, including show notes. I made it mostly because I wanted it for myself, but it should be useful to other people as well.

Behaviour
---------
The script takes an RSS feed URL and a (local) target directory as arguments. The feed will be downloaded to the specified directory (as `feed.rss`) and then used to download the episodes. Audio files are downloaded from the server and not altered (except for the title). The show notes will be saved to individual HTML files.

The filename is used to determine if an episode has already been downloaded, in which case it will not be downloaded again (unless the `-f|--force` flag is set). The script will decide how it would name the file, then see if that file already exists. That means it will not recognize episodes that were downloaded with different settings (like `-d|--date` or `-e|--episode-number`).

An index.html file will be created in the target directory. This file contains an overview of all audio files, as well as links to the show notes. Any index.html file that already exists will be overwritten.

For each episode, two files will be created:

    [title] - [filename on server including suffix]

and

    [title].description.html

Usage
-----
    [perl] ./podarchive.pl [options] rss_feed_url target_directory

_`[options]` can be placed wherever you want._
    
### Options
_You can try them out by using the `-n|--dry-run` flag_

    --keep,           -k: Don't refresh the feed file if it has already been downloaded
    --date,           -d: Prepend the publishing date to the filename for improved sorting. This would be useful for all podcasts that don't neatly include the number in every episode's title
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

### Configuration
There are no config files, everything is handled with command line arguments.

### Compatible Podcasts
`podarchive` should work with all podcasts using the standard RSS format.

For example, I have confirmed that it works with these podcasts:

* Hello Internet: http://www.hellointernet.fm/podcast?format=rss
* Accidental Tech Podcast: https://atp.fm/rss
* The Unmade Podcast: https://www.unmade.fm/episodes?format=rss

Operating Systems
-----------------
`podarchive` has been extensively tested on both macOS and FreeBSD, it also works on Linux

It seemed to work during my short tests in Windows 7 and 10 VMs.

Dependencies
------------
Please refer the `use` calls at the beginning of `podarchive.pl` for the used modules. I'm not putting a list here because im 100% sure I would forget updating it. You can also just try to run it, Perl should give you an error message about missing modules.

Compiled Binaries
-----------------
The `make.sh` (UNIX) and `make.bat` (Windows) scripts use [`pp`](https://metacpan.org/pod/pp) to create an independent binary file, which should then be able to run without having the dependencies installed. However, making the binary still requires the dependencies, so this is only useful if multiple computers **running the same operating system** are involved.

Since this still requires a lot of testing, I am not publishing binaries at the moment.

How I'm using it
----------------
`podcarchive` runs in a daily cronjob on my FreeBSD NAS. While Perl itself is installed, the required modules are not, so I am using a binary file created with `make.sh`.
