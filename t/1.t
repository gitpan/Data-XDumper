# $Id: 1.t,v 1.12 2003/02/20 01:30:04 xmath Exp $
# make; perl -Iblib/lib t/1.t
# vim: ft=perl

use lib 't/lib';
use Test::More tests => 23;

sub readlines ($) { map { chomp(my $x = <DATA>); $x } 1 .. $_[0] }

BEGIN { use_ok('Data::XDumper') };
Data::XDumper::Default->markro = 0;	# read-only flags are inconsistent

sub Foo::Bar {}

my $data = eval {
	open my $fh, '<', '';
	bless $fh, 'IO::Florp';

	my $q;
	my $x = [ 0, 9, 1234324, -1234324, "foo" ];
	my $y = { foo => \"blah\n\0hello", bar => $x, baz => qr/\w+/ };
	my $z = [[$fh, \*Foo::Bar, \*^G, sub{0}], $x, $y, \\$q];
	push @$z, [$z->[3]];
	push @$x, \$y->{bar};
	bless $z, 'Foo'
};
warn "$@\n" if $@;
isa_ok( $data, 'Foo' );

my $obj = new Data::XDumper usehex => 1;
isa_ok( $obj, 'Data::XDumper' );
ok( $obj->usehex );

my $default = Data::XDumper::Default;
isa_ok( $default, 'Data::XDumper' );

is( $obj->indent, $default->indent );
is( $obj->prefix, $default->prefix );
is( $obj->linelen, $default->linelen );
is( $obj->lformat, $default->lformat );

{
	$default->linelen++;
	is( $default->linelen, $obj->linelen+1 );
	my $foo = new Data::XDumper;
	is( $default->linelen, $foo->linelen );
	$default->linelen--;
	is( $default->linelen, $obj->linelen );
}

my $compare = [readlines(13)];
is_deeply( [$obj->dump($data)], $compare );
is_deeply( [Data::XDumper::Dump($data)], [readlines(13)] );

$default->usehex = 1;
is_deeply( [Data::XDumper::Dump($data)], $compare );
is_deeply( [Data::XDumper->dump($data)], $compare );

$obj->linelen = 30;
$obj->lformat = "A0";		# should not take effect until reset
is( $obj->linelen, 30 );
is( $obj->lformat, "A0" );

is_deeply( [$obj->dump($data)], [readlines(16)] );

$obj->usehex = 0;
$obj->indent = "   ";
$obj->linelen = 1;
$obj->reset;

ok( not $obj->usehex );
is( $obj->indent, "   " );
is( $obj->linelen, 1 );

is_deeply( [$obj->dump($data)], [readlines(27)] );

__DATA__
        \Foo @(
           [\IO::Florp <anon> *{'$fh'}, \*Foo::Bar, \*^G, \&('t/1.t':22)],
           \
@L002:        @(0, 9, 0x12d594, -0x12d594, 'foo', \$L001),
           {
$L001:        bar => \@L002,
              baz => \Regexp qr/(?-xism:\w+)/,
              foo => \"blah\n\0hello"
           },
           \
$L003:        \undef,
           [\$L003]
        )
        \Foo @(
           [\IO::Florp <anon> *{'$fh'}, \*Foo::Bar, \*^G, \&('t/1.t':22)],
           \
@L002:        @(0, 9, 1234324, -1234324, 'foo', \$L001),
           {
$L001:        bar => \@L002,
              baz => \Regexp qr/(?-xism:\w+)/,
              foo => \"blah\n\0hello"
           },
           \
$L003:        \undef,
           [\$L003]
        )
        \Foo @(
           [
              \IO::Florp <anon> *{'$fh'},
              \*Foo::Bar,
              \*^G,
              \&('t/1.t':22)
           ],
           \@L002,
           {
              bar => $L001,
              baz => \Regexp qr/(?-xism:\w+)/,
              foo => \"blah\n\0hello"
           },
           \$L003,
           [\$L003]
        )
        \Foo @(
           [
              \IO::Florp <anon> *{'$fh'},
              \*Foo::Bar,
              \*^G,
              \&('t/1.t':22)
           ],
           \
@A1:          @(
                 0,
                 9,
                 1234324,
                 -1234324,
                 'foo',
                 \$A0
              ),
           {
$A0:          bar => \@A1,
              baz => \Regexp qr/(?-xism:\w+)/,
              foo => \"blah\n\0hello"
           },
           \
$A2:          \undef,
           [
              \$A2
           ]
        )
