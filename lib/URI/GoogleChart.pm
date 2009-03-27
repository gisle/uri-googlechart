package URI::GoogleChart;

use strict;

our $VERSION = "0.02";

use URI;
use Carp qw(croak carp);

my $BASE = "http://chart.apis.google.com/chart";

our %TYPE_ALIAS = (
    "lines" => "lc",
    "sparklines" => "ls",
    "xy-lines" => "lxy",

    "horizontal-stacked-bars" => "bhs",
    "vertical-stacked-bars" => "bvs",
    "horizontal-grouped-bars" => "bhg",
    "vertical-grouped-bars" => "bvg",

    "pie" => "p",
    "pie-3d" => "p3",
    "concentric-pie" => "pc",

    "venn" => "v",
    "scatter-plot" => "s",
    "radar" => "r",
    "radar-splines" => "rs",
    "google-o-meter" => "gom",

    "africa" => "t",
    "asia" => "t",
    "europe" => "t",
    "middle_east" => "t",
    "south_america" => "t",
    "usa" => "t",
    "world" => "t",
);

our %COLOR_ALIAS = (
    "red" => "FF0000",
    "blue" => "0000FF",
    "green" => "00FF00",
    "yellow" => "FFFF00",
    "white" => "FFFFFF",
    "black" => "000000",
    "transparent" => "FFFFFFFF",
);

# constants for data encoding
my @C = ("A" .. "Z", "a" .. "z", 0 .. 9, "-", ".");
my $STR_s = join("", @C[0 .. 61]);
my $STR_e = do {
    my @v;
    for my $x (@C) {
	for my $y (@C) {
	    push(@v, "$x$y");
	}
    }
    join("", @v);
};
die unless length($STR_s) == 62;
die unless length($STR_e) == 4096 * 2;


sub new {
    my($class, $type, $width, $height, %opt) = @_;

    croak("Chart type not provided") unless $type;
    croak("Chart size not provided") unless $width && $height;

    my %param = (
	cht => $TYPE_ALIAS{$type} || $type,
	chs => join("x", $width, $height),
    );
    $param{chtm} = $type if $param{cht} eq "t" && $type ne "t";  # maps

    my %handle = (
	data => \&_data,
	group => 1,
	min => 1,
	max => 1,
	encoding => 1,

	color => sub {
	    my $v = shift;
	    $v = [$v] unless ref($v);
	    for (@$v) {
		if (my $c = $COLOR_ALIAS{$_}) {
		    $_ = $c;
		}
		elsif (/^[\da-fA-F]{3}\z/) {
		    $_ = join("", map "$_$_", split(//, $_));
		}
	    }
	    $param{chco} = join(",", @$v);
	},
	title => sub {
	    my $title = shift; 
	    ($title, my($color, $size)) = @$title if ref($title) eq "ARRAY";
	    $param{chtt} = $title;
	    if (defined($color) || defined($size)) {
		$color = "" unless defined $color;
		$size = "" unless defined $size;
		$param{chts} = "$color,$size";
	    }
	},
	margin => sub {
	    my $m = shift;
	    $m = [($m) x 4] unless ref($m);
	    $param{chma} = join(",", @$m);
	}
    );

    for my $k (keys %opt) {
	if (my $h = $handle{$k}) {
	    $h->($opt{$k}, \%param, \%opt) if ref($h) eq "CODE";
	}
	else {
	    $param{$k} = $opt{$k};
	    carp("Unrecognized parameter '$k' embedded in GoogleChart URI")
		unless $k =~ /^ch/;
	}
    }

    # generate URI
    my $uri = URI->new($BASE);
    $uri->query_form(map { $_ => $param{$_} } _sort_chart_keys(keys %param));
    for ($uri->query) {
	s/%3A/:/g;
	s/%2C/,/g;
	s/%7C/|/g; # XXX doesn't work (it ends up encoded anyways)
	$uri->query($_);
    }
    return $uri;
}

sub _sort_chart_keys {
    my %o = ( cht => 1, chtm => 2, chs => 3 );
    return sort { ($o{$a}||=99) <=> ($o{$b}||=99) || $a cmp $b } @_;
}

sub _default_minmax {
    my $param = shift;
    my $t = $param->{cht};
    return 0, undef if $t =~ /^p/;  # pie chart
    return 0, undef if $t eq "v";   # venn
    return 0, undef if $t =~ /^r/;  # radar chart
    return 0, undef if $t =~ /^b/;  # bar chart
    return 0, 100   if $t eq "gom"; # meter
    return;
}

sub _data {
    my($data, $param, $opt) = @_;

    # various shortcuts
    $data = _deep_copy($data);  # want to modify it
    if (ref($data) eq "ARRAY") {
	$data = [$data] unless ref($data->[0]);
    }
    elsif (ref($data) eq "HASH") {
	$data = [$data];
    }
    else {
	$data = [[$data]];
    }

    my $group = _deep_copy($opt->{group});
    $group->{""}{min} = $opt->{min};
    $group->{""}{max} = $opt->{max};

    for my $set (@$data) {
	$set = { v => $set } if ref($set) eq "ARRAY";
	my $v = $set->{v};
	my $g = $set->{group} ||= "";

	my($min, $max) = _default_minmax($param);
	for (@$v) {
	    next unless defined;
	    $min = $_ if !defined($min) || $_ < $min;
	    $max = $_ if !defined($max) || $_ > $max;
	}

	if (defined $min) {
	    my %h = (min => $min, max => $max);
	    for my $k (keys %h) {
		if (defined $set->{$k}) {
		    $h{$k} = $set->{$k};
		}
		else {
		    $set->{$k} = $h{$k};
		}

		my $gv = $group->{$g}{$k};
		if (!defined($gv) ||
		    ($k eq "min" && $h{$k} < $gv) ||
		    ($k eq "max" && $h{$k} > $gv)
		   )
		{
		    $group->{$g}{$k} = $h{$k};
		}
	    }
	}
    }

    #use Data::Dump; dd $data;
    #use Data::Dump; dd $group;

    # encode data
    my $e = $opt->{encoding} || "t";
    my %enc = (
	t => {
	    null => -1,
	    sep1 => ",",
	    sep2 => "|",
	    fmt => sub {
		my $v = 100 * shift;
		$v = sprintf "%.1f", $v if $v != int($v);
		$v;
	    },
	},
	s => {
	    null => "_",
	    sep1 => "",
	    sep2 => ",",
	    fmt => sub {
		return substr($STR_s, $_[0] * length($STR_s) - 0.5, 1);
	    },
	},
	e => {
	    null => "__",
	    sep1 => "",
	    sep2 => ",",
	    fmt => sub {
		return substr($STR_e, int($_[0] * length($STR_e) / 2 - 0.5) * 2, 2);
	    },
	}
    );
    my $enc = $enc{$e} || croak("unsupported encoding $e");
    my @res;
    for my $set (@$data) {
        my($min, $max) = @{$group->{$set->{group}}}{"min", "max"};
	my $v = $set->{v};
	for (@$v) {
	    if (defined($_) && $_ >= $min && $_ <= $max && $min != $max) {
		$_ = $enc->{fmt}(($_ - $min) / ($max - $min));
	    }
	    else {
		$_ = $enc->{null};
	    }
	}
	push(@res, join($enc->{sep1}, @$v));
    }
    $param->{chd} = "$e:" . join($enc->{sep2}, @res);
}

sub _deep_copy {
    my $o = shift;
    return $o unless ref($o);
    return [map _deep_copy($_), @$o] if ref($o) eq "ARRAY";
    return {map { $_ => _deep_copy($o->{$_}) } keys %$o} if ref($o) eq "HASH";
    die "Can't copy " . ref($o);
}

1;

__END__

=head1 NAME

URI::GoogleChart - Generate Google Chart URIs

=head1 SYNOPSIS

 use URI::GoggleChart;
 my $chart = URI::GoogleChart->new("line", 300, 100,
     data => [45, 80, 100, 33],
 );

=head1 DESCRIPTION

This module provide a constructor method for Google Chart URIs.  Google will
serve back PNG images of charts controlled by the provided parameters when
these URI are dereferenced.  Normally these URIs will be embedded as C<< <img
src='$chart'> >> tags in HTML documents.

The Google Chart service is described at L<http://code.google.com/apis/chart/>
and these pages also define the API in terms of the parameters these URIs
take.  This module make it easier to generate URIs that conform to this API as
it automatically takes care of data encoding and scaling, as well as hiding
most of the cryptic parameter names that the API uses in order to generate
shorter URIs.

The following constructor method is provided:

=over

=item $uri = URI::GoogleChart->new( $type, $width, $height, %opt )

The constructor method's 3 first arguments are mandatory and they define the
type of chart to generate and the dimension of the image in pixels.
The rest of the arguments are provided as key/value pairs.  The return value
is an HTTP L<URI> object, which can also be treated as a string.

The $type argument can either be one of the type code documented at the Google
Charts page or one of the following more readable aliases:

    lines
    sparklines
    xy-lines

    horizontal-stacked-bars
    vertical-stacked-bars
    horizontal-grouped-bars
    vertical-grouped-bars

    pie
    pie-3d
    concentric-pie

    venn
    scatter-plot
    radar
    radar-splines
    google-o-meter

    world
    africa
    asia
    europe
    middle_east
    south_america
    usa

The key/value pairs can either be one of the C<chXXX> codes documented on the
Google Chart pages or one of the following:

=over

=item data => [{ v => [$v1, $v2,...], %opt }, ...]

=item data => [[$v1, $v2,...], [$v1, $v2,...], ...]

=item data => [$v1, $v2,...]

=item data => $v1

The data to be charted is provided as an array of data series.  Each series is
defined by a hash with the C<v> element being an array of data points in the
series.  Missing data points should be provided as C<undef>.  Other hash
elements can be provided to define various properties of the series.  These are
described below.

As a short hand when you don't need to define other properties besides the data
points you can just provide an array of numbers instead of the series hash.

As a short hand when you only have a single data series, you can just provide a
single array of numbers, and finally if you only have a single number you can
provide it without wrapping it in an array.

The following data series properties can be provided.

The "group" property can be used to group data series together.  Series that
have the same group value belong to the same group.  Values in the same group
are scaled based on the minimum and maximum data point provided in that group. 
Data series without a "group" property belong to the default group.

=item min => $num

=item max => $num

Defines the minimum and maximum value for the default group.  If not provided
the minimum and maximum is calculated from the data points belonging to this
group.  Chart types that plot relative values make the default minimum 0 so
the relative size of the data points stay the same after scaling.

The data points are scaled so that they are plotted relative to the ($min ..
$max) range.  For example if the ($min .. $max) range is (5 .. 10) then a data
point value of 7.5 is plotted in the middle of the chart area.

=item group => { $name => { min => $min, max => $max }, ...},

Define parameters for named data series groups.  Currently you can only set
up the minimum and maximum values used for scaling the data points.

=item encoding => "t"

=item encoding => "s"

=item encoding => "e"

Select what kind of data encoding you want to be used.   They differ in the
resolution they provide and in their readability and verbosity.  Resolution
matters if you generate big charts.  Verbosity matters as some web client might
refuse to dereference URLs that are too long.

The "t" encoding is the most readable and verbose.  It might consume up to 5
bytes per data point. It provide a resolution of 1/1000.

The "s" encoding is the most compact; only consuming 1 byte per data point.  It
provide a resolution of 1/62.

The "e" encoding provides the most resolution and it consumes 2 bytes per data
point.  It provide a resolution of 1/4096.

The default encoding is currently "t"; but expect this to change.  The default
ought to be automatically selected based on the resolution of the chart and
the number of data points provided.

=item color => $color

=item color => [$color1, $color2, ...]

Sets the colors to use for charting the data series.  The canonical form for
$color is hexstrings either of "RRGGBB" or "RRGGBBAA" form.  When you use this
interface you might also use "RGB" form as well as some comon names like "red",
"blue", "green", "white", "black",... which are expanded to the canonical form
in the URI.

=item title => $str

=item title => { text => $str, color => $color, fontsize => $fontsize }

Sets the title for the chart; optionally changing the color and fontsize used
for the title.

=item margin => $num

=item margin => [ $left, $right, $top, $bottom ]

Sets the chart margins in pixels.  If a single number is provided then all
the margins are set to this number of pixels.

=back

=back

=head1 SEE ALSO

L<http://code.google.com/apis/chart/>

L<URI>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Gisle Aas.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
