#!/usr/bin/perl

while (<>) {

    if (/^(\s*\S+\s+)\\([^\s]+)\s+\($/) {

        my $prefix = $1;
        my $inst = $2;

        $inst =~ s/\[/_/g;
        $inst =~ s/\]/_/g;
        $inst =~ s/\./_/g;

        $_ = "${prefix}${inst} (\n";
    }

    print;
}