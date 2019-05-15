#!/usr/bin/perl

# This script is based on the btree.pl that I wrote as part of a little
# experiment: https://dev.yorhel.nl/doc/pwlookup
#
# It is hardcoded to use gzip (because that's available in a standard Perl
# distribution) compression level 9 (saves a few MiB with no noticable impact
# on lookup performance) with 4k block sizes (because that is fast enough and
# offers good compression).
#
# Creating the database:
#
#   perl PWlookup.pm create <sorted-dictionary >dbfile
#
# Extracting all passwords from the database:
#
#   perl PWLookup.pm extract dbfile >sorted-dictionary
#
# Performing lookups (from the CLI):
#
#   perl PWLookup.pm lookup dbfile query
#
# Performing lookups (from Perl):
#
#   use PWLookup;
#   my $pw_exists = PWLookup::lookup($dbfile, $query);

package PWLookup;

use strict;
use warnings;
use v5.10;
use Compress::Zlib qw/compress uncompress/;
use Encode qw/encode_utf8 decode_utf8/;

my $blocksize = 4096;

# Encode/decode a block reference, [ leaf, length, offset ]. Encoded in a single 64bit integer as (leaf | length << 1 | offset << 16)
sub eref($) { pack 'Q', ($_[0][0]?1:0) | $_[0][1]<<1 | $_[0][2]<<16 }
sub dref($) { my $v = unpack 'Q', $_[0]; [$v&1, ($v>>1)&((1<<15)-1), $v>>16] }

# Write a block and return its reference.
sub writeblock {
    state $off = 0;
    my $buf = compress($_[0], 9);
    my $len = length $buf;
    print $buf;
    my $oldoff = $off;
    $off += $len;
    [$_[1], $len, $oldoff]
}

# Read a block given a file handle and a reference.
sub readblock {
    my($F, $ref) = @_;
    die $! if !sysseek $F, $ref->[2], 0;
    die $! if $ref->[1] != sysread $F, (my $buf), $ref->[1];
    uncompress($buf)
}

sub encode {
    my $leaf = "\0";
    my @nodes = ('');
    my $ref;

    my $flush = sub {
        my $minsize = $_[0];
        return if $minsize > length $leaf;

        my $str = $leaf =~ /^\x00([^\x00]*)/ && $1;
        $ref = writeblock $leaf, 1;
        $leaf = "\0";
        $nodes[0] .= "$str\x00".eref($ref);

        for(my $i=0; $i <= $#nodes && $minsize < length $nodes[$i]; $i++) {
            my $str = $nodes[$i] =~ s/^([^\x00]*)\x00// && $1;
            $ref = writeblock $nodes[$i], 0;
            $nodes[$i] = '';
            if($minsize || $nodes[$i+1]) {
                $nodes[$i+1] ||= '';
                $nodes[$i+1] .= "$str\x00".eref($ref);
            }
        }
    };

    my $last;
    while((my $p = <STDIN>)) {
        chomp($p);
        # No need to store passwords that are rejected by form validation
        if(!length($p) || length($p) > 500 || !eval { decode_utf8((local $_=$p), Encode::FB_CROAK); 1 }) {
            warn sprintf "Rejecting: %s\n", ($p =~ s/([^\x21-\x7e])/sprintf '%%%02x', ord $1/ger);
            next;
        }
        # Extra check to make sure the input is unique and sorted according to Perl's string comparison
        if(defined($last) && $last ge $p) {
            warn "Rejecting due to uniqueness or incorrect sorting: $p\n";
            next;
        }
        $leaf .= "$p\0";
        $flush->($blocksize);
    }
    $flush->(0);
    print eref $ref;
}


sub lookup_rec {
    my($F, $q, $ref) = @_;
    my $buf = readblock $F, $ref;
    if($ref->[0]) {
        return $buf =~ /\x00\Q$q\E\x00/;
    } else {
        while($buf =~ /(.{8})([^\x00]+)\x00/sg) {
            return lookup_rec($F, $q, dref $1) if $q lt $2;
        }
        return lookup_rec($F, $q, dref substr $buf, -8)
    }
}

sub lookup {
    my($f, $q) = @_;
    open my $F, '<', $f or die $!;
    sysseek $F, -8, 2 or die $!;
    die $! if 8 != sysread $F, (my $buf), 8;
    lookup_rec($F, encode_utf8($q), dref $buf)
}


sub extract_rec {
    my($F, $ref) = @_;
    my $buf = readblock $F, $ref;
    if($ref->[0]) {
        print "$1\n" while $buf =~ /\x00([^\x00]+)/g;
    } else {
        extract_rec($F, dref $1) while $buf =~ /(.{8})[^\x00]+\x00/sg;
        extract_rec($F, dref substr $buf, -8)
    }
}

sub extract {
    my($f) = @_;
    open my $F, '<', $f or die $!;
    sysseek $F, -8, 2 or die $!;
    die $! if 8 != sysread $F, (my $buf), 8;
    extract_rec($F, dref $buf)
}


if(!caller) {
    encode() if $ARGV[0] eq 'create';
    extract($ARGV[1]) if $ARGV[0] eq 'extract';
    printf "%s\n", lookup($ARGV[1], decode_utf8 $ARGV[2]) ? 'Found' : 'Not found' if $ARGV[0] eq 'lookup';
}

1;
