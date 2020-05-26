#!/bin/sh
# This command compiles this program into an executable binary file.
# The binary file will be named "podarchive-cli". For some reason it needs to have the same name as the Perl file for this to work.

# pp fails to detect and include some necessary modules, these need to be manually added via the '-M' flags

# This command was tested on:
# [x] macOS
# [ ] Linux
# [ ] FreeBSD

pp -v podarchive-cli.pl podarchivelib.pl \
   -o podarchive-cli \
 -M XML::RSS::Parser::Element\
 -M XML::RSS::Parser::Feed\
 -M XML::RSS::Parser::Characters\
 -M XML::SAX::Expat
