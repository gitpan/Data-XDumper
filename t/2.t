# $Id: 2.t,v 1.7 2003/02/19 23:15:00 xmath Exp $
# make; perl -Iblib/lib t/2.t
# vim: ft=perl

use lib 't/lib';
use Test::More tests => 8;

sub readlines ($) {
	return wantarray
		? map { chomp(my $x = <DATA>); $x } 1 .. $_[0]
		: join '', map scalar(<DATA>), 1 .. $_[0]
}

BEGIN { use_ok('Data::XDumper') }
Data::XDumper::Default->markro = 0;	# readonly flags are inconsistent

my $dump = new Data::XDumper usehex => 1;
isa_ok( $dump, 'Data::XDumper' );

is( scalar $dump->dump([1, 2, 1024]), scalar readlines(1),
	"Array of hex numbers" );
is_deeply( [$dump->dump({ foo => sub{0}, 'bar ' => ["\n"] })], [readlines(1)],
	"Hash of code ref and string with newline" );

$dump->usehex = 0;
is( scalar $dump->dump([1, 2, 1024]), scalar readlines(1), "Decimal numbers" );

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
is( $$data, scalar readlines(1), "Different indent" );
}

BEGIN { use_ok( 'Data::XDumper', qw(Dump) ) }

is( (scalar Dump [1, "x" x 60, 42]), scalar readlines(5), "Expanded array" );

__DATA__
        [1, 2, 0x400]
        {'bar ' => ["\n"], foo => \&('t/2.t':22)}
        [1, 2, 1024]
$L001:  ['foo', \$L001]
        [
          1,
          'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          42
        ]
