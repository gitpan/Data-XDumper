# $Id: 3.t,v 1.7 2003/02/19 23:15:00 xmath Exp $
# make; perl -Iblib/lib t/3.t
# vim: ft=perl

use lib 't/lib';
use Test::More;

BEGIN {
	if ($] < 5.008) {
		plan skip_all => "DumpVar requires perl 5.8";
	} else {
		plan tests => 6;
	}
}

sub readlines ($) {
	return wantarray
		? map { chomp(my $x = <DATA>); $x } 1 .. $_[0]
		: join '', map scalar(<DATA>), 1 .. $_[0]
}

BEGIN { use_ok('Data::XDumper', qw(DumpVar)) }
Data::XDumper::Default->markro = 0;	# readonly flags are inconsistent

sub foo {}

is_deeply( [DumpVar $foo], [readlines(1)], "Dump scalar variable" );
is_deeply( [DumpVar %foo], [readlines(1)], "Dump hash variable" );
is_deeply( [DumpVar @foo], [readlines(1)], "Dump array variable" );
is_deeply( [DumpVar *foo], [readlines(1)], "Dump glob variable" );
is_deeply( [DumpVar &foo], [readlines(1)], "Dump code variable" );

__DATA__
        undef
        %()
        @()
        *foo
        &('t/3.t':25)
