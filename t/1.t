# $Id: 1.t,v 1.2 2003/02/13 16:24:34 xmath Exp $
# make; perl -Iblib/lib t/1.t
# vim: ft=perl sts=0 noet sw=8 ts=8

use lib 't/lib';
use Test::More tests => 23;

sub readlines ($) { map { chomp(my $x = <DATA>); $x } 1 .. $_[0] }

BEGIN { use_ok('Data::XDumper') };

my $data = eval {
	open my $fh, '<', '';
	open my $fg, '<', '';
	bless $fg, 'IO::InnerFile';

	my $q;
	my $x = [ 0, 9, 1234324, -1234324, "foo" ];
	my $y = { foo => \"blah\n\0hello", bar => \$x };
	my $z = \(\$q);
	push @$x, \$y->{bar};
	return bless [[$fh, $if, \*Foo::Bar, sub{}], $x, $y, $z, [\$q]], 'Foo';
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

my $compare = [readlines(11)];
is_deeply( [$obj->dump($data)], $compare );
is_deeply( [Data::XDumper::Dump($data)], [readlines(11)] );

$default->usehex = 1;
is_deeply( [Data::XDumper::Dump($data)], $compare );
is_deeply( [Data::XDumper->dump($data)], $compare );

$obj->linelen = 30;
$obj->lformat = "A0";		# should not take effect until reset
is( $obj->linelen, 30 );
is( $obj->lformat, "A0" );

is_deeply( [$obj->dump($data)], [readlines(18)] );

$obj->usehex = 0;
$obj->indent = "   ";
$obj->linelen = 1;
$obj->reset;

ok( not $obj->usehex );
is( $obj->indent, "   " );
is( $obj->linelen, 1 );

is_deeply( [$obj->dump($data)], [readlines(31)] );

__DATA__
        Foo [
            ARRAY [GLOB *'main::$fh', undef, GLOB *'Foo::Bar', CODE],
L003:       ARRAY [0, 9, 0x12d594, -0x12d594, 'foo', REF \L002],
            HASH {
L002:           bar => REF \L003,
                foo => SCALAR \"blah\n\0hello"
            },
            REF \
L001:           SCALAR \undef,
            ARRAY [L001]
        ]
        Foo [
            ARRAY [GLOB *'main::$fh', undef, GLOB *'Foo::Bar', CODE],
L003:       ARRAY [0, 9, 1234324, -1234324, 'foo', REF \L002],
            HASH {
L002:           bar => REF \L003,
                foo => SCALAR \"blah\n\0hello"
            },
            REF \
L001:           SCALAR \undef,
            ARRAY [L001]
        ]
        Foo [
            ARRAY [
                GLOB *
                    'main::$fh',
                undef,
                GLOB *
                    'Foo::Bar',
                CODE
            ],
            L003,
            HASH {
                bar => L002,
                foo => SCALAR \
                    "blah\n\0hello"
            },
            REF \L001,
            ARRAY [L001]
        ]
        Foo [
           ARRAY [
              GLOB *
                 'main::$fh',
              undef,
              GLOB *
                 'Foo::Bar',
              CODE
           ],
A2:        ARRAY [
              0,
              9,
              1234324,
              -1234324,
              'foo',
              REF \
                 A1
           ],
           HASH {
A1:           bar => REF \
                 A2,
              foo => SCALAR \
                 "blah\n\0hello"
           },
           REF \
A0:           SCALAR \
                 undef,
           ARRAY [
              A0
           ]
        ]
