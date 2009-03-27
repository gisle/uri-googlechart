#!perl -w

use strict;
use Test;
plan tests => 1;

use URI::GoogleChart;

open(my $fh, ">", "examples.html") || die "Can't create examples.html: $!";
print $fh <<EOT;
<html>
<head>
  <title>URI::GoogleChart Examples</title>
  <style>
  body {
    margin: 20px 50px;
    background-color: #ddd;
    max-width: 700px;
    font-family: sans-serif;
  }
  div.eg {
    background-color: #eee;
    padding: 10px 20px;
    border: 1px solid #aaa;
    margin: 30px 0;
    -webkit-box-shadow: 5px 5px 5px #aaa;
  }
  .even {
    background-color: #edf5ff;
  }
  pre {
    margin: 0px;
    font-weight: bold;
  }
  .uri {
    font-size: x-small;
  }
  img {
    border: 1px solid #aaa;
    padding: 5px;
    margin: 15px 0;
  }
  </style>
</head>

<body>
<h1>URI::GoogleChart Examples</h1>

<p> This page shows Perl code snippets using the <a
href="http://search.cpan.org/dist/URI-GoogleChart">URI::GoogleChart</a> module
to generate chart URLs and the corresponding images that the <a
href="http://code.google.com/apis/chart/">Google Chart service</a> generate
from them.

</p>

EOT

chart("pie-3d", 250, 100,
    data => [60, 40],
    chl => "Hello|World",
);

chart("pie", 500, 150,
    data => [80, 20],
    color => ["yellow", "black"],
    chl => "Resembes Pack-man|Does not resemble Pac-man",
    chf => "bg,s,000000",
    chp => 0.6,
    margin => [0, 30, 10, 10],
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

chart("europe", 300, 150,
    color => ["white", "green", "red"],
    chf => "bg,s,EAF7FE", # water
    # nordic populations 
    chld => "NOSEDKFIIS",
    data => [4.5e6, 9e6, 5.3e6, 5.1e6, 307261],
);


print $fh <<EOT;

<p style="font-size: small;">Page generated with URI::GoogleChart v$URI::GoogleChart::VERSION</p>
</body>
</html>
EOT

ok(close($fh));

sub chart {
    my $uri = URI::GoogleChart->new(@_);

    (undef, undef, my $line) = caller;
    seek(DATA, 0, 0);
    <DATA> while --$line;
    my $src = <DATA>;
    unless ($src =~ /;$/) {
	while (<DATA>) {
	    $src .= $_;
	    last if /^\);/;
	}
    }
    $src =~ s/^chart/\$u = URI::GoogleChart->new/;

    print $fh <<EOT
  <div class="eg">
    <pre class="src">$src</pre>
    <div><img src='$uri'></div>
    <span class="uri">$uri</span>
  </div>
EOT
}

__END__
