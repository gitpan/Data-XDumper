# $Id: 2.t,v 1.1 2003/02/13 16:25:29 xmath Exp $
# make; perl -Iblib/lib t/1.t
# vim: ft=perl sts=0 noet sw=8 ts=8

use lib 't/lib';
use Test::More tests => 8;

sub readlines ($) {
	return wantarray
		? map { chomp(my $x = <DATA>); $x } 1 .. $_[0]
		: join '', map scalar(<DATA>), 1 .. $_[0]
}

BEGIN { use_ok('Data::XDumper') }

my $dump = new Data::XDumper usehex => 1;
isa_ok( $dump, 'Data::XDumper' );

is( scalar $dump->dump([1, 2, 1024]), scalar readlines(1) );
is_deeply( [$dump->dump({ foo => sub{}, 'bar ' => ["\n"] })], [readlines(1)] );

$dump->usehex = 0;
is( scalar $dump->dump([1, 2, 1024]), scalar readlines(1) );

my $test = ["foo"];
push @$test, \$test;
Data::XDumper::Default->indent = "  ";

# time to intercept output
{
package Intercept;
sub TIEHANDLE { bless \(my $x), shift }
sub PRINT { my $x = shift; $$x .= $_ for @_; 1 }
}
{
local *FH;
my $data = tie *FH, 'Intercept';
my $old = select FH;
Data::XDumper::Dump $test;
select $old;
is( $$data, scalar readlines(1) );
}

BEGIN { use_ok( 'Data::XDumper', qw(Dump) ) }

is( (scalar Dump [1, "x" x 60, 42]), scalar readlines(5) );

__DATA__
        ARRAY [1, 2, 0x400]
        HASH {bar  => ARRAY ["\n"], foo => CODE}
        ARRAY [1, 2, 1024]
L001:   ARRAY ['foo', REF \L001]
        ARRAY [
          1,
          'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          42
        ]
