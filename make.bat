:: This script compiles podarchive into an executable binary.
:: The output file will be named "podarchive.exe".

:: More information about pp: https://metacpan.org/pod/pp

:: pp fails to detect and include some necessary modules, these need to be added manually via the '-M' flags

pp -v podarchive.pl ^
   -o podarchive.exe ^
   -l libexpat-1__.dll^
 -M XML::RSS::Parser::Element^
 -M XML::RSS::Parser::Feed^
 -M XML::RSS::Parser::Characters^
 -M XML::Parser::Expat^
 -M XML::SAX::Expat

