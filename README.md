README
======
This is a simple script to archive podcasts. It takes the URL as of an RSS feed and the path of a target directory as arguments.
If an episode is already downloaded, it will not be downloaded again. This is determined by the filename.


For each episode, two files will be created:

    [title] - [filename on server including suffix]

and

    [title].description.html
    

Usage
-----
    cd podcast-archiver
    ./cli.pl [RSS feed URL] [desired target directory]