package HTML::HTML5::Sanity;

use 5.008001;
use strict;
use warnings;

our $VERSION = '0.01';

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = (
	'all'       => [ qw(fix_document document_to_hashref document_to_clarkml element_to_hashref element_to_clarkml attribute_to_hashref attribute_to_clarkml) ],
	'debug'     => [ qw(document_to_hashref document_to_clarkml element_to_hashref element_to_clarkml attribute_to_hashref attribute_to_clarkml) ],
	'standard'  => [ qw(fix_document document_to_hashref document_to_clarkml) ],
	);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT    = ( @{ $EXPORT_TAGS{'standard'} } );

use HTML::Entities qw(encode_entities_numeric);
use XML::LibXML qw(:ns :libxml);

sub fix_document
{
	my $old_document        = shift;
	my $attribute_behaviour = shift || 0;
	
	my $new_document        = XML::LibXML::Document->new;
	
	my $new_root = fix_element(
		$old_document->documentElement,
		$new_document,
		{ ':' => 'http://www.w3.org/1999/xhtml', 'xml' => XML_XML_NS }
		);
		
	$new_document->setDocumentElement($new_root);
	
	return $new_document;
}

sub fix_element
{
	my $old_element         = shift;
	my $new_document        = shift;
	my $parent_declarations = shift;
	
	my $declared_namespaces = {};
	foreach my $k (keys %{$parent_declarations})
	{
		$declared_namespaces->{$k} = $parent_declarations->{$k};
	}
	
	# Process namespace declarations on this element.
	foreach my $attr ($old_element->attributes)
	{
		next if $attr->nodeType == XML_NAMESPACE_DECL;
		
		if ($attr->nodeName =~ /^xmlns:(.*)$/)
		{
			my $prefix = $1;
			
			if ($prefix eq 'xml' && $attr->getData eq XML_XML_NS)
			{
				# that's OK.
			}
			elsif ($prefix eq 'xml' || $attr->getData eq XML_XML_NS)
			{
				next;
			}
			elsif ($prefix eq 'xmlns' || $attr->getData eq XML_XMLNS_NS)
			{
				next;
			}
			
			$declared_namespaces->{ $prefix } = $attr->getData;
		}
	}
	
	# Process any default XML Namespace
	my $hasExplicit = 0;
	if ($old_element->hasAttributeNS(undef, 'xmlns'))
	{
		$hasExplicit = 1;
		$declared_namespaces->{ ':' } = $old_element->getAttributeNS(undef, 'xmlns');
	}
	
	# Create a new element.
	my $new_element;
	if ($hasExplicit)
	{
		$new_element = $new_document->createElementNS(
			$declared_namespaces->{ ':' },
			$old_element->nodeName,
			);
	}
	else
	{
		my $tag = $old_element->nodeName;
		if ($tag =~ /^([^:]+)\:([^:]+)$/)
		{
			my $ns_prefix = $1;
			my $localname = $2;
			
			if (defined $declared_namespaces->{$ns_prefix})
			{
				$new_element = $new_document->createElementNS(
					$declared_namespaces->{$ns_prefix},	$tag);
			}
		}
		unless ($new_element)
		{
			$new_element = $new_document->createElementNS(
				$declared_namespaces->{ ':' }, $tag);
		}
	}
	
	# Add attributes to new element.
	foreach my $old_attr ($old_element->attributes)
	{
		next if $old_attr->nodeType == XML_NAMESPACE_DECL;
		# next if $old_attr->nodeName =~ /^xmlns(:.*)?$/;
		
		fix_attribute($old_attr, $new_element, $declared_namespaces);
	}
	
	# Process child nodes.
	foreach my $old_kid ($old_element->childNodes)
	{
		if ($old_kid->nodeType == XML_TEXT_NODE
		||  $old_kid->nodeType == XML_CDATA_SECTION_NODE)
		{
			$new_element->appendTextNode($old_kid->nodeValue);
		}
		elsif ($old_kid->nodeType == XML_COMMENT_NODE)
		{
			$new_element->appendChild(
				$new_document->createComment($old_kid->nodeValue)
				);
		}
		elsif ($old_kid->nodeType == XML_ELEMENT_NODE)
		{
			$new_element->appendChild(
				fix_element($old_kid, $new_document, $declared_namespaces)
				);
		}
	}
	
	return $new_element;
}

sub fix_attribute
{
	my $old_attribute       = shift;
	my $new_element         = shift;
	my $declared_namespaces = shift;
	
	my $name = $old_attribute->nodeName;
	my @new_attribute;
	
	if ($name =~ /^([^:]+)\:([^:]+)$/)
	{
		my $ns_prefix = $1;
		my $localname = $2;
		
		if (defined $declared_namespaces->{$ns_prefix})
		{
			@new_attribute = (
				$declared_namespaces->{$ns_prefix},
				sprintf("%s:%s", $ns_prefix, $localname),
				);
		}
	}
#	elsif ($attribute_behaviour)
#	{
#		@new_attribute = (
#			'http://www.w3.org/1999/xhtml',
#			$name,
#			);
#	}
	if (@new_attribute)
	{
		$new_element->setAttributeNS(@new_attribute, $old_attribute->nodeValue);
	}
	else
	{
		$new_element->setAttribute($name, $old_attribute->nodeValue);
	}
	
	return undef;
}

sub document_to_hashref
{
	my $n = shift;
	
	return {
		'type'   => 'Document',
		'root'   => element_to_hashref($n->documentElement),
		};
}

sub element_to_hashref
{
	my $n = shift;
	
	my $rv = {
		'type'    => 'Element',
		'qname'   => $n->nodeName,
		'prefix'  => $n->prefix,
		'suffix'  => $n->localname,
		'nsuri'   => $n->namespaceURI,
		'attributes' => [],
		'children'   => [],
		};
	
	foreach my $attr ($n->attributes)
	{
		my $x = attribute_to_hashref($attr);
		push @{ $rv->{'attributes'} }, $x if $x;
	}
	
	foreach my $kid ($n->childNodes)
	{
		if ($kid->nodeType == XML_TEXT_NODE
		||  $kid->nodeType == XML_CDATA_SECTION_NODE)
		{
			push @{ $rv->{'children'} }, $kid->nodeValue;
		}
		elsif ($kid->nodeType == XML_COMMENT_NODE)
		{
			push @{ $rv->{'children'} }, comment_to_hashref($kid);
		}
		elsif ($kid->nodeType == XML_ELEMENT_NODE)
		{
			push @{ $rv->{'children'} }, element_to_hashref($kid);
		}
	}
	
	return $rv;
}

sub comment_to_hashref
{
	my $n = shift;
	
	return {
		'type'    => 'Comment',
		'comment' => $n->nodeValue,
		};
}

sub attribute_to_hashref
{
	my $n = shift;
	
	if ($n->nodeType == XML_NAMESPACE_DECL)
	{
		return {
			'type'    => 'Attribute (XMLNS)',
			'qname'   => $n->nodeName,
			'prefix'  => $n->prefix,
			'suffix'  => $n->getLocalName,
			'nsuri'   => $n->getNamespaceURI,
			'value'   => $n->getData,
		};
	}
	
	return {
		'type'    => 'Attribute',
		'qname'   => $n->nodeName,
		'prefix'  => $n->prefix,
		'suffix'  => $n->localname,
		'nsuri'   => $n->namespaceURI,
		'value'   => $n->nodeValue,
		};
}

sub document_to_clarkml
{
	my $n = shift;
	
	element_to_clarkml($n->documentElement);
}

sub element_to_clarkml
{
	my $n = shift;
	
	my $rv;
	
	if (defined $n->namespaceURI)
	{
		$rv = sprintf("<{%s}%s", $n->namespaceURI, $n->localname);
	}
	else
	{
		$rv = sprintf("<%s", $n->localname);
	}
	
	foreach my $attr ($n->attributes)
	{
		my $x = attribute_to_clarkml($attr);
		$rv .= " $x" if $x;
	}
	
	if (! $n->childNodes)
	{
		return $rv . "/>";
	}
	
	$rv .= ">";
	
	foreach my $kid ($n->childNodes)
	{
		if ($kid->nodeType == XML_TEXT_NODE
		||  $kid->nodeType == XML_CDATA_SECTION_NODE)
		{
			$rv .= encode_entities_numeric($kid->nodeValue);
		}
		elsif ($kid->nodeType == XML_COMMENT_NODE)
		{
			$rv .= "<!--" . $kid->nodeValue . "-->";
		}
		elsif ($kid->nodeType == XML_ELEMENT_NODE)
		{
			$rv .= element_to_clarkml($kid);
		}
	}
	
	if (defined $n->namespaceURI)
	{
		$rv .= sprintf("</{%s}%s>", $n->namespaceURI, $n->localname);
	}
	else
	{
		$rv .= sprintf("</%s>", $n->localname);
	}
	
	return $rv;
}

sub attribute_to_clarkml
{
	my $n = shift;

	if ($n->nodeType == XML_NAMESPACE_DECL)
	{
		if (defined $n->getLocalName)
		{
			return sprintf("{%s}%s=\"%s\"",
				$n->getNamespaceURI, $n->getLocalName, $n->getData);
		}
		return sprintf("{%s}XMLNS=\"%s\"",
			$n->getNamespaceURI, $n->getData);
	}
	
	if (defined $n->namespaceURI)
	{
		return sprintf("{%s}%s=\"%s\"",
			$n->namespaceURI, $n->localname, $n->nodeValue);
	}
	else
	{
		return sprintf("%s=\"%s\"",
			$n->localname, $n->nodeValue);
	}
}

1;
__END__

=head1 NAME

HTML::HTML5::Sanity - Perl extension to make HTML5 DOM trees less insane.

=head1 SYNOPSIS

  use HTML::HTML5::Parser;
  use HTML::HTML5::Sanity;
  
  my $parser    = HTML::HTML5::Parser->new;
  my $html5_dom = $parser->parse_file('http://example.com/');
  my $sane_dom  = fix_document($html5_dom);
  
  print document_to_clarkml($sane_dom);

=head1 DESCRIPTION

The Document Object Model (DOM) generated by HTML::HTML5::Parser meets
the requirements of the HTML5 spec, but will probably catch a lot of
people by surprise.

The main oddity is that elements and attributes which appear to be
namespaced are not really. For example, the following element:

  <div xml:lang="fr">...</div>

Looks like it should be parsed so that it has an attribute "lang" in
the XML namespace. Not so. It will really be parsed as having the
attribute "xml:lang" in the null namespace.

=over 8

=item C<fix_document>

  $sane_dom = fix_document($html5_dom);

Returns a modified copy of the DOM and leaving the original DOM
unmodified.

=item C<document_to_clarkml>, C<element_to_clarkml>, C<attribute_to_clarkml>, 

  $string = document_to_clarkml($document);
  $string = element_to_clarkml($element);
  $string = attribute_to_clarkml($attribute);

Returns a Clark-Notation-like string useful for debugging. Only the 
first function, which takes an XML::LibXML::Document is exported by
default, but by choosing an export list of ":all" or ":debug" will
export the others too.

=item C<document_to_hashref>, C<element_to_hashref>, C<attribute_to_hashref>, 

  $data = document_to_hashref($document);
  $data = element_to_hashref($element);
  $data = attribute_to_hashref($attribute);

Returns a hashref useful for debugging. Only the first function, which
takes an XML::LibXML::Document is exported by default, but by choosing
an export list of ":all" or ":debug" will export the others too.

=back

=head1 BUGS

Please report any bugs to L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<HTML::HTML5::Parser>, L<XML::LibXML>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Toby Inkster

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
