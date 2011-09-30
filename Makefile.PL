use strict;
use warnings;

use inc::Module::Install;

my $dist = 'HTML-HTML5-Sanity';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

requires            'Locale::Country'        => '1.06';
test_requires       'Test::More'             => '0.61';
requires            'XML::LibXML'            => '1.60';
test_requires       'XML::LibXML::Debugging' => 0;

resources(
	'homepage'   => "https://metacpan.org/release/$dist",
	'repository' => "http://goddamn.co.uk/svn-web/perlmods/browse/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);
	
keywords qw(HTML HTML5 Markup Fixer Fix Attributes Namespaces XML DOM Lang Language);
	
write_doap_changes;
write_doap_changes_xml;
auto_license;
auto_manifest;

auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
