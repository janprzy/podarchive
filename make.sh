#!/bin/sh
# This command compiles this program into an executable binary file.

# pp fails to detect and include some necessary modules, these need to be manually added via the '-M' flags

pp -v cli.pl podarchivelib.pl \
   -o cli \
 -M XML::RSS::Parser::Element\
 -M XML::RSS::Parser::Feed\
 -M XML::RSS::Parser::Characters\
 -M XML::SAX::Expat
