package URI::GoogleChart;

use strict;

our $VERSION = "0.01";

use URI;
use Carp qw(croak);

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

    for (keys %opt) {
	# ...
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

sub default_minmax {
    my $self = shift;
    my $t = $self->{p}{cht};
    return 0, undef if $t =~ /^p/;  # pie chart
    return 0, undef if $t eq "v";   # venn
    return 0, undef if $t =~ /^r/;  # radar chart
    return 0, undef if $t =~ /^b/;  # bar chart
    return 0, 100   if $t eq "gom"; # meter
    return;
}

sub data {
    my $self = shift;
    my @data = ref($_[0]) ? @_ : \@_;
    my %group;
    for my $set (@data) {
	$set = { v => $set } if ref($set) eq "ARRAY";
	my $v = $set->{v};
	my $g = $set->{group} ||= "";

	my($min, $max) = $self->default_minmax;
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

		my $gv = $group{$g}{$k};
		if (!defined($gv) ||
		    ($k eq "min" && $h{$k} < $gv) ||
		    ($k eq "max" && $h{$k} > $gv)
		   )
		{
		    $group{$g}{$k} = $h{$k};
		}
	    }
	}
    }

    # save these; mostly for debugging purposes
    $self->{data} = \@data;
    $self->{group} = \%group;

    # encode data
    my @enc;
    for my $set (@data) {
	my @v = @{$set->{v}};
        my($min, $max) = @{$group{$set->{group}}}{"min", "max"};
	for (@v) {
	    if (defined) {
		if ($_ < $min || $_ > $max) {
		    $_ = -1;
		}
		elsif ($min == $max) {
		    $_ = 0;
		}
		else {
		    $_ = 100 * ($_ - $min) / ($max - $min);
		    $_ = sprintf "%.0f", $_;
		}
	    }
	    else {
		$_ = -1;
	    }
	}
	push(@enc, join(",", @v));
    }
    $self->{p}{chd} = "t:" . join("|", @enc);
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

=item data => [$v1, $v2,...]

=item data => [[$v1, $v2,...], [$v1, $v2,...], ...]

=item data => [{v => [$v1, $v2,...], %opt}, ...]

Provides the data to be charted.  Missing data points should be provided as C<undef>. 

=item min => $num

=item max => $num

Defines the minimum and maximum value for the default group.

=item group => { $name => { min => $min, max => $max }, ...},

Define parameters for named data series groups.

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
