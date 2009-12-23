use strict;
use warnings;

use inc::Module::Install;

license             'perl';

name                'HTML-HTML5-Sanity';
author              'Toby Inkster <tobyink@cpan.org>';
perl_version_from   'lib/HTML/HTML5/Sanity.pm';
version_from        'lib/HTML/HTML5/Sanity.pm';
abstract_from       'lib/HTML/HTML5/Sanity.pm';

test_requires       'Test::More'        => '0.61';

requires            'Locale::Country'   => '1.06';
requires            'XML::LibXML'       => 0;

auto_set_homepage;
auto_set_bugtracker;

include 'Test::Signature';
auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
