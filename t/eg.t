#!perl -w

use strict;
use Test;
plan tests => 1;

use URI::GoogleChart;

open(my $fh, ">", "eg.html") || die "Can't create eg.html: $!";
print $fh <<EOT;
<html>
<head>
  <title>URI::GoogleChart Examples</title>
  <style>
  body {
    margin: 20px 50px;
    background-color: #ddd;
  }
  div.eg {
    padding: 10px;
  }
  .even {
    background-color: #edf5ff;
  }
  .uri {
    font-size: smaller;
  }
  img {
    border: 1px solid #888;
    padding: 4px;
  }
  </style>
</head>
<body>
<h1>URI::GoogleChart Examples</h1>
EOT

chart("pie-3d", 250, 100,
    data => [60, 40],
    chl => "Hello|World",
);

chart("lines", 200, 125,
    data => [40,60,60,45,47,75,70,72,],
    min => 0, max => 100,
);

chart("sparklines", 200, 125,
    data => [27,25,60,31,25,39,25,31,26,28,80,28,27,31,27,29,26,35,70,25],
    min => 0, max => 100,
);

chart("lxy", 200, 125,
    data => [
        [10,20,40,80,90,95,99],
	[20,30,40,50,60,70,80],
        [undef],
        [5,25,45,65,85],
    ],
    color => [qw(3072F3 red)],
);

chart("horizontal-stacked-bars", 200, 150,
    data => [
        [10,50,60,80,40],
	[50,60,100,40,20],
    ],
    min => 0, max => 200,
    color => [qw(3072F3 f00)],
);

chart("vertical-grouped-bars", 300, 125,
    data => [
        [10,50,60,80,40],
	[50,60,100,40,20],
    ],
    min => 0, max => 100,
    chco => "3072F3,ff0000",
);

chart("gom", 125, 80, data => 80, chl => 80, title => "Awsomness");
chart("usa", 200, 100);


print $fh <<EOT;
</body>
</html>
EOT

ok(close($fh));

my $count;
sub chart {
    $count++;
    my $class = "eg";
    $class .= " even" if $count % 2 == 0;
    my $uri = URI::GoogleChart->new(@_);
    print $fh qq(<div class="$class"><span class="uri">$uri</span><br><img src='$uri'></div>\n);
}
