# $Id: 1.t,v 1.1 2003/02/13 13:24:48 xmath Exp $
# make; perl -Iblib/lib t/1.t

use lib 't/lib';
use Test::More tests => 1;
no strict;
no warnings;

BEGIN { use_ok('Data::XDumper') };

# vim: ft=perl sts=0 noet sw=8 ts=8
