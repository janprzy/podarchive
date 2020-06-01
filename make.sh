#!/bin/sh
# This script compiles podarchive into an executable binary.
# The output file will be named "podarchive". It only works on the same operating system it was created on.

# More information about pp: https://metacpan.org/pod/pp

# pp fails to detect and include some necessary modules, these need to be added manually via the '-M' flags

# This was tested on:
# [x] macOS
# [x] Linux
# [x] FreeBSD

pp -v podarchive.pl \
   -o podarchive \
 -M XML::RSS::Parser::Element\
 -M XML::RSS::Parser::Feed\
 -M XML::RSS::Parser::Characters\
 -M XML::SAX::Expat
