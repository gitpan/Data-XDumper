# $Id: XDumper.pm,v 1.28 2003/02/18 00:42:00 xmath Exp $

use 5.006;
use strict;
use warnings;

package Data::XDumper;

our $VERSION = "1.02";

use Carp;
use Data::Dumper ();	# to borrow qquote()
use B::More "1.01";

use base 'Exporter';
our @EXPORT_OK = qw(Dump DumpVar);

use constant Default => sub{my%x=@_;bless\%x,__PACKAGE__}->(
	prefix	=> "        ",
	indent	=> "   ",
	linelen	=> 75,
	lformat	=> 'L001',
	usehex	=> 0,
	markro	=> 1
);

sub new : method {
	my ($class, %options) = @_;
	my %self = %{+Default};
	@self{keys %options} = values %options;
	(bless \%self, $class)->reset
}

BEGIN {
	no strict 'refs';
	for my $p (qw(prefix indent linelen lformat usehex markro)) {
		*$p = sub : lvalue { $_[0]{$p} };
	}
}

sub reset : method {
	my ($obj) = @_;
	$obj->{curlabel} = $obj->lformat;
	$obj->{seen} = {};
	$obj
}

sub Dump { @_ = (__PACKAGE__, map \$_, splice @_); goto &dumprefs }
sub dump : method { push @_, map \$_, splice @_, 1; goto &dumprefs }

BEGIN {
	*DumpVar = ($] >= 5.008)
		? sub (\[$@%&*]) { unshift @_, __PACKAGE__; goto &dumprefs }
		: sub ($) { croak "DumpVar requires perl 5.8 or later" };
}

sub dumprefs : method {
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

my %vartypes = ( AV => '@', HV => '%', CV => '&', GV => '*', IV => '$',
	NV => '$', RV => '$', PV => '$', PVIV => '$', PVMG => '$', NULL => '$',
	FM => '&', IO => '?');

sub _dump : method {
	no warnings 'uninitialized';
	my ($obj, $val, $q, $prefix) = @_;
	my $sv = B::svref_2object($val);
	my $type = B::class($sv);

	if ($type eq 'SPECIAL') {
		$val = $$sv;
		if ($val == ${+B::sv_undef}) {
			$val = "<undef>";
		} elsif ($val == ${+B::sv_yes}) {
			$val = "<yes>";
		} elsif ($val == ${+B::sv_no}) {
			$val = "<no>";
		} else {
			$val = "SPECIAL(???)";
		}
		goto trivial;
	}

	if (exists $obj->{seen}->{$$sv}) {
		$val = $obj->{seen}->{$$sv} ||=
			$vartypes{$type} . $obj->{curlabel}++;
trivial:	$val = $prefix . $val;
		return sub {
			$_[0] = 0 if @_;
			wantarray ? $obj->prefix . $val : $val
		};
	}

	if ($type eq 'PVMG' && $sv->magic =~ /[Ppq]/) {
		my $x = $$val;
	}

	my $label = \$obj->{seen}->{$$sv};
	my @data; my $cb = "";
	my $flags = $sv->FLAGS;

	if ($flags & 0x1000) {
		my $bless = ref($val);
		$prefix .= ($bless =~ /^(?:\w+::)*\w+\z/
			? $bless : _qquote($bless)) . ' ';
	}

	$prefix .= "<ro> " if ($flags & 0x800000) && $obj->markro;

	if ($type eq 'NULL') {
		$val = 'undef';
	} elsif ($type eq 'HV') {
		@data = map [ /^(?:\w+::)*\w+\z/ ? "$_ => " : _qquote($_) .
			' => ', \$val->{$_} ], sort keys %$val;
		$prefix .= '%';
		goto structured;
	} elsif ($type eq 'AV') {
		@data = map ['', \$_], @$val;
		$prefix .= '@';
		goto structured;
	} elsif ($type eq 'GV') {
		my $pkg = $sv->STASH->NAME . "::";
		my $name = $sv->NAME;
		$prefix .= "<anon> " if \$sv->STASH->svref->{$name} != $val;
		$pkg = "{" . _qquote($pkg) . "}" if $pkg !~ /^\w+::\z/;
		$pkg = "" if $pkg eq 'main::';
		if ($name =~ /^[\001-\032\037]\z/) {
			$name = sprintf "^%c", ord($name)+64;
		} elsif ($name !~ /^\w+\z/) {
			$name = "{" . _qquote($name) . "}";
		}
		$val = "*$pkg$name";
	} elsif ($type eq 'IO') {
		$val = "<io>";	# nothing of interest I can dump afaics
	} elsif ($type eq 'CV' || $type eq 'FM') {
		$prefix .= "<format> " and $type = 'FORM' if $type eq 'FM';
		my ($file, $line);
		my $g = $sv->GV;
		if ($g->$type && ${$g->$type} == $$sv) {
			$file = $g->FILE;
			$line = $g->LINE;
		} elsif ((my $op = $sv->START)->isa('B::COP')) {
			$file = $op->file;
			$line = $op->line;
		} else {
			$file = $sv->FILE;
			$line = "unknown";
		}
		$file = _qquote($file) unless $file =~ /^[\w.-]*\z/;
		$val = "&(" . $file . ":" . $line . ")";
	} elsif ($type eq 'PVLV' && $sv->TYPE eq '.') {
		@data = ['', $sv->TARG->svref];
		$prefix .= "pos";
		goto structured;
	} elsif ($type eq 'PVLV' && 1+index('xv', $sv->TYPE)+1) {
		@data = map ['', $_],
			$sv->TARG->svref, \$sv->TARGOFF, \$sv->TARGLEN;
		$prefix .= $sv->TYPE eq 'x' ? "substr" : "vec";
		goto structured;
	} elsif ($type eq 'PVMG' && 1+index($sv->magic, 'r')) {
		$val = "$val";
		$val =~ s|/|\\/|g;
		$val = "qr/$val/";
	} elsif ($flags & 0x80000) {
		$val = $$val;
		my $rclass = B::class($sv = $sv->RV);
		$prefix .= '<weak> ' if $flags & 0x80000000;
		push @$q, sub { $val = $obj->_dump($val, $q, '') };
		return sub {
			return if $$label && !wantarray;
			my @data;
			my $op = $obj->prefix;
			if (defined (my $data = $val->($rclass))) {
				@data = ($data);
			} else {
				return unless wantarray;
				if ($rclass) {
					local $obj->{prefix} = $op
						. $obj->indent;
					@data = ('', $val->($rclass));
				} else {
					@data = $val->($rclass);
					substr($data[0], 0, length($op)) = "";
				}
			}
			my $prefix = wantarray ? $op . $prefix : $prefix;
			if ($rclass eq 'AV') {
				$prefix .= '[';  $cb = ']';
			} elsif ($rclass eq 'HV') {
				$prefix .= '{';  $cb = '}';
			} else {
				$prefix .= "\\";
			}
			push @data, $op if $cb && @data > 1;
			$data[0] = $prefix . $data[0];  $data[-1] .= $cb;
			substr($data[0], 0, 1+length $$label) = "$$label:"
				if $$label;
			return wantarray ? @data : $data[0];
		};
	} elsif ($flags & 0x04040000) {
		$val = _qquote($$val);
	} elsif ($obj->usehex && $flags & 0x01010000) {
		$val = int $$val;
		if ($val > 9 && $val <= 0xFFFFFFFF) {
			$val = sprintf '0x%x', $val;
		} elsif ($val < -9 && $val >= -0xFFFFFFFF) {
			$val = sprintf '-0x%x', -$val;
		}
	} elsif ($flags & 0x03030000) {
		$val = $$val + 0;
	} else {
		$val = 'undef';
	}

	$val = $prefix . $val;
	return sub {
		return $$label ? undef : $val unless wantarray;
		$val = $obj->prefix . $val;
		substr($val, 0, 1 + length $$label) = "$$label:" if $$label;
		$val
	};

structured:
	push @$q, sub { $_ = $obj->_dump($_->[1], $q, $_->[0]) for @data; }
		if @data;

	return sub {
		return unless wantarray || !$$label;
		my $prefix = $prefix;
		my $op = $obj->prefix;
		if (!$_[0] || length($prefix) > 1 || $$label) {
			$prefix .= "(";
			$prefix = $op . $prefix if wantarray;
			substr($prefix, 0, 1+length($$label)) = "$$label:"
				if $$label;
			$_[0] = 0;
		} else {
			$prefix = "";
		}
		my @out;
		my $len = $obj->linelen - length($prefix) + 1;
		$len -= length($op) unless $prefix && wantarray;
		for (@data) {
			push @out, scalar $_->();
			pop(@out), goto expanded unless defined $out[-1];
			goto expanded if ($len -= length($out[-1]) + 2) < 0;
		}
		$prefix ||= $op if wantarray;
		return $prefix . join(', ', @out) . ($prefix && ")");
	expanded:
		return unless wantarray;
		my $n = @out;
		goto noindent unless $prefix;
		local $obj->{prefix} = $op . $obj->indent;
	noindent:
		{ my $op = $obj->prefix; $_ = "$op$_," for @out; }
		for (@data) {
			next if $n-- > 0;
			push @out, $_->();
			$out[-1] .= ",";
		}
		chop $out[-1];
		if ($prefix) {
			unshift @out, $prefix;
			push @out, "$op)";
		}
		return @out;
	};
}

sub _qquote {
	return Data::Dumper::qquote($_[0]) unless $_[0] =~ /^[\x20-\x7E]*\z/;
	my $data = shift;
	$data =~ s/('|\\)/\\$1/g;
	return "'$data'";
}


1;


=head1 NAME

Data::XDumper - Accurate human-readable dumps of perl data structures with
labeled cross-references.

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

    use Data::XDumper qw(Dump DumpVar);

    print scalar Dump [1, "x" x 60, 42];

    my %x = (foo => 1, bar => 2, baz => 3);
    DumpVar %x;		# requires perl 5.8 or later

=head1 DESCRIPTION

Produces dumps of almost any kind of perl datastructure, in a format which
I personally find a lot more readable than that of Data::Dumper.

Perhaps more important is that it produces much more accurate dumps, that
almost exactly mirror the internal structure of the data.

The dump returns the output lines in list context.  Otherwise it produces a
big string containing the whole dump, and in void context prints it too.

There are a few settings you can set on the dumper object.  When you create
a new dumper, it inherits the settings from the default object, which is
returned by C<Data::XDumper::Default>.

=head2 Methods

=over 4

=item I<$OBJ>->dumprefs(I<LIST>)

Dump the list of references.  This is the primary dumping method.
Everything else eventually calls this method.

=item I<$OBJ>->dump(I<LIST>)

Dump the list of scalars.

=item I<PACKAGE>->dump(I<LIST>)

Dump the list of scalars using the default object (see C<Functions> below).

=item I<$OBJ>->reset

Reset the dumper object to its initial state.  This clears the list of
references it has seen, and resets the label counter.

=back

=head2 Properties

=over 4

=item I<$OBJ>->usehex

Use hexadecimal notation for integers in range -0xFFFFFFFF .. -0xA and
0xA .. 0xFFFFFFFF.  Default: off

=item I<$OBJ>->indent

The string used to increase the indentation level.  Default: 3 spaces

=item I<$OBJ>->prefix

The string prefixed to every output line.  Note that this string should
accomodate space for the labels.  Default: 8 spaces

=item I<$OBJ>->linelen

The maximum desired line length.  If a single-line form of a value exceeds
this length, XDumper will use multi-line form instead.  Default: 75

=item I<$OBJ>->lformat

The format for labels.  Must match /^[A-Za-z0-9]+\z/.  You need to reset
the object before change of label format takes effect.  Default: "L001"

=item I<$OBJ>->markro

Whether to explicitly mark read-only values by prefixing them with <ro>.
Default: on

=back

=head2 Functions

=over 4

=item Dump I<LIST>

Dump the list of scalars using the default object.

=item DumpVar I<VARIABLE>

Dump the variable using the default object.  Requires perl 5.8 or later.

=item Default

Returns the default object, to allow you to change its settings.

=back

=head1 KNOWN ISSUES

The code is ugly and devoid of comments.  The documentation is too brief.
But it does seem to work though :-)

Formatting GVs, CVs and FMs still needs improvement.  And I don't really
know yet what to do with IO (if anything).

=head1 AUTHOR

Matthijs van Duin <xmath@cpan.org>

Copyright (C) 2003  Matthijs van Duin.  All rights reserved.
This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
