# $Id: 4.t,v 1.9 2003/02/20 01:30:04 xmath Exp $
# make; perl -Iblib/lib t/4.t
# vim: ft=perl

use lib 't/lib';
use Test::More tests => 4;

sub readlines ($) {
	return wantarray
		? map { chomp(my $x = <DATA>); $x } 1 .. $_[0]
		: join '', map scalar(<DATA>), 1 .. $_[0]
}

{
	package Foo;
	sub TIESCALAR { bless \@_, shift }
	sub TIEARRAY { bless \@_, shift }
	sub FETCH { $_[0][$_[1] || 0] }
	sub FETCHSIZE { scalar @{$_[0]} }
}

BEGIN { use_ok('Data::XDumper', qw(Dump)) }
Data::XDumper::Default->markro = 0;	# readonly flags are inconsistent

sub foo {}

open FH, '<', $0;

format FH =
   Foo!
.

my $data = sub { push @_, @_; \@_ }->(
	42, 1e42, "foo", \$foo, \%foo, \@foo, *foo, \*foo, \&foo, \&bar,
	*FH{IO}, undef);

is_deeply( [Dump $data], [readlines(32)], "Various kinds of values" );

my $fmtchk = [readlines(3)];
SKIP: {
	skip "FORMAT doesn't work in perl 5.6.0", 1 if $] < 5.006_001;
	is_deeply( [Dump *FH{FORMAT}, [*FH{FORMAT}]->[0]], $fmtchk, "FORMAT" );
}

use constant c => 'foo';

my $x = c;
$x = undef;	# $x is still a PV, not NULL! (perl only upgrades, never down)

tie $y, "Foo", 42;
tie @y, "Foo", 1, 2, 3;

is_deeply( [Dump c, $x, $y, \@y], [readlines(4)], "Ties and misc" );

__DATA__
        [
           42,
           1e+42,
           'foo',
           \
$L002:        undef,
           \
%L003:        %(),
           \
@L004:        @(),
*L001:     *foo,
           \*L001,
           \
&L005:        &('t/4.t':25),
           \
&L006:        &('t/4.t':34),
           \
?L007:        IO::Handle <io>,
           <undef>,
           42,
           1e+42,
           'foo',
           \$L002,
           \%L003,
           \@L004,
           <anon> *foo,
           \*L001,
           \&L005,
           \&L006,
           \?L007,
           undef
        ]
        \
&L001:     <format> &('t/4.t':27)
        \&L001
        'foo'
        undef
        42
        [1, 2, 3]
