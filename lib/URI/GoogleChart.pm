package URI::GoogleChart;

use strict;

our $VERSION = "0.01";

use URI;
use Carp qw(croak carp);

my $base = "http://chart.apis.google.com/chart";

our %type_alias = (
    "lines" => "lc",
    "sparklines" => "ls",
    "xy-lines" => "lxy",

    "horizontal-stacked-bars" => "bhs",
    "vertical-stacked-bars" => "bvs",
    "horizontal-grouped-bars" => "bhg",
    "vertcal-grouped-bars" => "bvg",

    "pie" => "p",
    "pie-3d" => "p3",
    "concentric-pie" => "pc",

    "venn" => "v",
    "scatter-plot" => "s",
    "radar" => "r",
    "radar-splines" => "rs",
    "map" => "t",
    "google-o-meter" => "gom",
);

sub new {
    my($class, $type, $width, $height, %opt) = @_;

    croak("Chart type not provided") unless $type;
    croak("Chart size not provided") unless $width && $height;

    $type = $type_alias{$type} || $type;

    my %param = (
	cht => $type,
	chs => join("x", $width, $height),
    );

    my %handle = (
	data => \&_data,
	group => 1,
	min => 1,
	max => 1,
	encoding => 1,

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
    my $uri = URI->new($base);
    $uri->query_form(map { $_ => $param{$_} } _sort_chart_keys(keys %param));
    for ($uri->query) {
	s/%3A/:/g;
	s/%2C/,/g;
	s/%7C/|/g;
	$uri->query($_);
    }
    return $uri;
}

sub _sort_chart_keys {
    my %o = ( cht => 1, chs => 2 );
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

This module provide a constructor function for Google Chart URIs.

=over

=item $uri = URI::GoogleChart->new( $type, $width, $height, %opt )

The constructor method's 3 first arguments are mandatory and they define the
type of chart to generate and the dimention of the image in pixels.
The rest of the arguments are provided as key/value pairs.

The $type can either be one of the type code documented at the Google Charts
page or one of the following more readable aliases:

    lines
    sparklines
    xy-lines

    horizontal-stacked-bars
    vertical-stacked-bars
    horizontal-grouped-bars
    vertcal-grouped-bars

    pie
    pie-3d
    concentric-pie

    venn
    scatter-plot
    radar
    radar-splines
    map
    google-o-meter

The key/value pairs can either be one of the documented C<chXXX> codes or one
of the following:

=over

=item data => $v1

=item data => [$v1, $v2,...]

=item data => [[$v1, $v2,...], [$v1, $v2,...], ...]

=item data => [{v => [$v1, $v2,...], %opt}, ...]

Provides the data to be charted.  Missing data points should be provided as C<undef>. 

=item min => $num

=item max => $num

Defines the minimum and maximum value for the default group.

=item group => { $name => { min => $min, max => $max }, ...},

Define parameters for named data series groups.

=item encoding => "t"

=item encoding => "s"

=item encoding => "e"

Select what kind of data encoding you want to be used.

=item title => $str

=item title => { text => $str, color => $color, fontsize => $fontsize }

Sets the title for the chart; optionally changing the color and fontsize used.

=item margin => $num

=item margin => { left => $n, right => $n, top => $n, bottom => $n }

Sets the chart margin

=back

=back

=head1 SEE ALSO

L<http://code.google.com/apis/chart/>

L<URI>
