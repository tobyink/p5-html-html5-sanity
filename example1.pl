use lib "lib/";
use lib "../HTML-HTML5-Parser/lib/";

use HTML::HTML5::Parser;
use HTML::HTML5::Sanity;

use Data::Dumper;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Quotekeys = 0;

my $parser = HTML::HTML5::Parser->new;
my $dom    = $parser->parse_string(<<HTML);
<html
	foo="bar"
	xmlns:quux="http://example.com/"
	quux:xyzzy="xyzzy"
	baz:baz="baz"
	>
<body xml:lang="en">
	<!--Hello-->
	<foo xmlns="http://example.net/">
		<bar />
	</foo>
	<foot:x xmlns:foot="http://example.net/">
		<bar />
	</foot:x>
</body>
</html>
HTML

my $sane = fix_document($dom);

print "========\n";
print HTML::HTML5::Sanity::document_to_clarkml($dom)."\n";
print "--------\n";
print HTML::HTML5::Sanity::document_to_clarkml($sane)."\n";
print "========\n";
