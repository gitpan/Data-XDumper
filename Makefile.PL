# $Id: Makefile.PL,v 1.2 2003/02/13 16:31:59 xmath Exp $

use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME		=> 'Data::XDumper',
	VERSION_FROM	=> 'XDumper.pm',
	PREREQ_PM	=> { Attribute::Property => 0 },
	ABSTRACT_FROM	=> 'XDumper.pm',
	AUTHOR		=> 'Matthijs van Duin <xmath@cpan.org>',
);
