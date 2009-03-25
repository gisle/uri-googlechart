#!perl

use strict;
use Test;
plan tests => 1;

use URI::GoogleChart;

my $u = URI::GoogleChart->new("lines", 200, 200);
ok($u, "http://chart.apis.google.com/chart?cht=lc&chs=200x200");
