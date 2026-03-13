#!/usr/bin/env bash

FILE="./target/sim/vsim/compile.cheshire_soc.tcl"

if [[ ! -f "$FILE" ]]; then
    echo "Error: $FILE not found in current directory."
    exit 1
fi

perl -0777 -i -pe '
s{
    (vcom\s+-2008.*?-93)        # match vcom block up to -93
    (.*?)                      # rest of block
    (/lib/([^/]+)/)            # capture library name
}{
    my $lib = $4;
    $1 =~ /-work/ ? "$1$2$3" : "$1 -work $lib$2$3"
}gsex
' "$FILE"