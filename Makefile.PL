# $Id: Makefile.PL,v 1.6 2003/02/17 13:44:46 xmath Exp $

use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME		=> 'Data::XDumper',
	VERSION_FROM	=> 'XDumper.pm',
	PREREQ_PM	=> {
		B::More => "1.01",
		Data::Dumper => 0,
	},
	ABSTRACT_FROM	=> 'XDumper.pm',
	AUTHOR		=> 'Matthijs van Duin <xmath@cpan.org>',
);
