# $Id: Makefile.PL,v 1.1 2003/02/13 13:24:48 xmath Exp $

use 5.006;
use ExtUtils::MakeMaker;

eval { mkdir "Data" and symlink "../XDumper.pm", "Data/XDumper.pm" };

WriteMakefile(
	NAME		=> 'Data::XDumper',
	VERSION_FROM	=> 'XDumper.pm',
	PREREQ_PM	=> { Attribute::Property => 0 },
	ABSTRACT_FROM	=> 'XDumper.pm',
	AUTHOR		=> 'Matthijs van Duin <xmath@cpan.org>',
);
