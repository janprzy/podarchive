#!/bin/sh
# This compiles the program into an executable binary file.
# The binary file will be named "podarchive". It only works on the same operating system it was created on.

# pp fails to detect and include some necessary modules, these need to be added manually via the '-M' flags

# This command was tested on:
# [x] macOS
# [ ] Linux
# [x] FreeBSD

pp -v podarchive.pl \
   -o podarchive \
 -M XML::RSS::Parser::Element\
 -M XML::RSS::Parser::Feed\
 -M XML::RSS::Parser::Characters\
 -M XML::SAX::Expat
