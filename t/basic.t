#!perl

use strict;
use Test;
plan tests => 2;

use URI::GoogleChart;

my $u;
$u = URI::GoogleChart->new("lines", 200, 200);
ok($u, "http://chart.apis.google.com/chart?cht=lc&chs=200x200");

$u = URI::GoogleChart->new("lines", 200, 200,
    data => [3,1,2],
    title => "foo",
    margin => 5,
);
ok($u, "http://chart.apis.google.com/chart?cht=lc&chs=200x200&chd=t:100,0,50&chma=5,5,5,5&chtt=foo");
