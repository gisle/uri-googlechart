package URI::GoogleChart;

use strict;

our $VERSION = "0.01";

use URI;
use Carp qw(croak);

my $base = "http://chart.apis.google.com/chart";

sub new {
    my($class, $type, $width, $height, %opt) = @_;

    croak("Chart type not provided") unless $type;
    croak("Chart size not provided") unless $width && $height;

    my $data = delete $opt{data};

    my $self = bless {
	p => {
	    cht => $type,
	    chs => join("x", $width, $height),
	    %opt,
	},
    }, $class;
    $self->data(@$data) if $data;

    return $self;
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

sub as_uri {
    my $self = shift;
    my $u = URI->new($base);
    $u->query_form($self->param);
    $u = $u->as_string;
    $u =~ s/%3A/:/g;
    $u =~ s/%2C/,/g;
    $u =~ s/%7C/|/g;
    return $u;
}

sub param {
    my $self = shift;
    my $p = $self->{p};
    return map { $_ => $p->{$_} } sort keys %$p;
}

1;
