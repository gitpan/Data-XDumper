# $Id: XDumper.pm,v 1.5 2003/02/13 16:35:40 xmath Exp $

use 5.006;
use strict;
use warnings;

package Data::XDumper;

our $VERSION = "1.01";

use Attribute::Property;
use Carp;
use Data::Dumper ();	# to borrow qquote()

use base 'Exporter';
our @EXPORT_OK = qw(Dump);

sub Dump { unshift @_, __PACKAGE__; goto &dump }

use constant Default => sub{my%x=@_;bless\%x,__PACKAGE__}->(
	prefix	=> "        ",
	indent	=> "    ",
	linelen	=> 75,
	lformat	=> 'L001',
);

sub new : method {
	my ($class, %options) = @_;
	my %self = %{+Default};
	@self{keys %options} = values %options;
	(bless \%self, $class)->reset
}

sub prefix : Property { defined }
sub indent : Property { defined }
sub linelen : Property { $_ > 0 }
sub usehex : Property { $_ = not !$_; 1 }
sub lformat : Property { /^[A-Za-z0-9]+\z/ }

sub reset : method {
	my ($obj) = @_;
	$obj->{curlabel} = $obj->lformat;
	$obj->{seen} = {};
	$obj
}

sub dump : method {
	my $obj = shift;
	$obj = Default->reset unless ref $obj;
	while (my ($k, $v) = each %{$obj->{seen}}) {
		delete $obj->{seen}->{$k} unless $v;
	}
	my @queue;
	my @data = map $obj->_dump($_, \@queue, ''), @_;
	$_->() for @queue;
	return wantarray
		? map $_->(), @data
		: (defined(wantarray) ? sub{$_[0]} : sub{print $_[0]})
			->(join("\n", map $_->(), @data) . "\n");
}

sub _dump : method {
	no warnings 'void';

	my ($obj, $val, $q, $prefix) = @_;
	my $type = ref $val;
	my @data; my $ob; my $cb;

	goto plain if !$type || exists $obj->{seen}->{$val};

	if (eval { %$val ; 1 }) {
		@data = map [ /^\w+/ ? "$_ => " : qquote($_) . ' => ',
			\$val->{$_} ], sort keys %$val;
		$ob = '{';  $cb = '}';
	} elsif (eval { @$val ; 1 }) {
		@data = map ['', \$_], @$val;
		$ob = '[';  $cb = ']';
	} elsif (eval { *$val ; 1 }) {
		@data = ['', \(*$val{PACKAGE} . '::' . *$val{NAME})];
		$ob = '*';  $cb = '';
	} elsif (eval { $$val ; 1 }) {
		@data = ['', $val];
		$ob = '\\';  $cb = '';
	} else {
plain:		if ($type) {
			$val = exists $obj->{seen}->{$val}
				? $obj->{seen}->{$val} ||= $obj->{curlabel}++
				: $type;
		} elsif (not defined $val) {
			$val = 'undef';
		} elsif ($val !~ /^(?:0|-?[1-9]\d*)(?:\.\d*)?(e[+-]\d+)?\z/) {
			$val = qquote($val);
		} elsif ($obj->usehex && $val =~ /^-?[1-9]\d+\z/) {
			no warnings 'numeric';
			if ($val > 0 && $val <= 0xFFFFFFFF) {
				$val = sprintf '0x%x', $val;
			} elsif ($val < 0 && $val >= -0xFFFFFFFF) {
				$val = sprintf '-0x%x', -$val;
			}
		}
		$val = $prefix . $val;
		return sub { wantarray ? $obj->prefix . $val : $val };
	}

	undef $obj->{seen}->{$val};

	$prefix .= "$type $ob";
	if (not @data) {
		$val = $prefix . $cb;
		return sub { wantarray ? $obj->prefix . $val : $val };
	}

	push @$q, sub { $_ = $obj->_dump(${$_->[1]}, $q, $_->[0]) for @data; };
	
	return sub {
		my $lprefix = $obj->prefix . $prefix;

		if (my $label = $obj->{seen}->{$val}) {
			return unless wantarray;
			$label .= ':';
			substr($lprefix, 0, length $label) = $label;
		}

		my $len = length($lprefix);
		my @lines = map { my $x = scalar $_->(); defined($x) && ($len +=
			length($x)) < $obj->linelen ? $x : goto expanded }
			@data;

		$lprefix = $prefix unless wantarray;
		return $lprefix . join(', ', @lines) . $cb;

expanded:	return unless wantarray;
		@lines = ($lprefix);
		{
			local $obj->{prefix} = $obj->prefix . $obj->indent;
			for (@data) {
				push @lines, $_->();
				$lines[-1] .= ',';
			}
			chop $lines[-1];
		}
		push @lines, $obj->prefix . $cb if $cb;
		return @lines;
	};
}

sub qquote {
	my $data = shift;
	if ($data =~ /^[\x20-\x7E]*\z/) {
		$data =~ s/('|\\)/\\$1/g;
		return "'$data'";
	}
	return Data::Dumper::qquote($data);
}


1;


=head1 NAME

Data::XDumper - Human readable dumps of perl data structures with labeled
cross-references.

=head1 SYNOPSIS

    use Data::XDumper;

    my $dump = new Data::XDumper usehex => 1;
    print scalar $dump->dump([1, 2, 1024]);
    print "$_\n" for $dump->dump({ foo => sub{}, 'bar ' => ["\n"] });
    $dump->usehex = 0;
    print scalar $dump->dump([1, 2, 1024]);

    my $test = ["foo"];
    push @$test, \$test;
    Data::XDumper::Default->indent = "  ";
    Data::XDumper::Dump $test;

    use Data::XDumper qw(Dump);

    print scalar Dump [1, "x" x 60, 42];

=head1 DESCRIPTION

Produces dumps of almost any kind of perl datastructure, in a format which
I personally find a lot more readable than that of Data::Dumper.

The dump returns the output lines in list context.  Otherwise it produces a
big string containing the whole dump, and in void context prints it too.

There are a few settings you can set on the dumper object.  When you create
a new dumper, it inherits the settings from the default object, which is
returned by C<Data::XDumper::Default>.

=head2 Methods

=over 4

=item I<PACKAGE>->dump(I<LIST>)

Dump the list of items using the default object (see C<Functions> below).

=item I<$OBJ>->dump(I<LIST>)

Dump the list of items.

=item I<$OBJ>->reset

Reset the dumper object to its initial state.  This clears the list of
references it has seen, and resets the label counter.

=back

=head2 Properties

=over 4

=item I<$OBJ>->usehex

Use hexadecimal notation for integers in range -0xFFFFFFFF .. -0xA and
0xA .. 0xFFFFFFFF.

=item I<$OBJ>->indent

The string used to increase the indentation level.

=item I<$OBJ>->prefix

The string prefixed to every output line.  Note that this string should
accomodate space for the labels.  By default it is 8 spaces.

=item I<$OBJ>->linelen

The maximum desired line length.  If a single-line form of a value exceeds
this length, XDumper will use multi-line form instead.

=item I<$OBJ>->lformat

The format for labels.  Must match /^[A-Za-z0-9]+\z/.  You need to reset
the object before change of label format takes effect.

=back

=head2 Functions

=over 4

=item Dump I<LIST>

Dump the list of items using the default object.

=item Default

Returns the default object, to allow you to change its settings.

=back

=head1 KNOWN ISSUES

The code is ugly and devoid of comments.  The documentation is too brief.
But it does seem to work though :-)

I'm still looking into what to do with CODE refs.. for now they're just
formatted as C<CODE>.

=head1 AUTHOR

Matthijs van Duin <xmath@cpan.org>

Copyright (C) 2003  Matthijs van Duin.  All rights reserved.
This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
