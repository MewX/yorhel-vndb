#!/usr/bin/perl

use strict;
use warnings;
use Cwd 'abs_path';

my $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/multi\.pl$}{} }

use lib $ROOT.'/lib';
use Multi::Core;

Multi::Core->run();
