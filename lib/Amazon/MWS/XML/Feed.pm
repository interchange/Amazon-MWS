package Amazon::MWS::XML::Feed;

use strict;
use warnings;
use utf8;

use XML::Compile::Schema;
use File::Spec;

use Moo;

=head1 NAME

Amazon::MWS::XML::Feed -- module to create XML feeds for Amazon MWS

=head1 ACCESSORS

=head2 schema_dir

The directory with the xsd files from amazon.

=head2 schema

The L<XML::Compile::Schema> object (built lazily).

=head2 merchant_id

Required. The merchant id provided by Amazon.

=head2 products

Required. An arrayref with products objects. The objects must respond
to the following methods:

=over 4

=item as_hash

The data structure to populate the Product stanza.

=cut


has schema_dir => (is => 'ro',
                   required => 1,
                   isa => sub {
                       die "Not a dir" unless -d $_[0];
                   });

has schema => (is => 'lazy');

has merchant_id => (is => 'ro',
                    required => 1,
                    isa => sub {
                        die "the merchant id must be a string" unless $_[0];
                    });

has products => (is => 'ro',
                 required => 1,
                 isa => sub {
                     die "Not an arrayref" unless ref($_[0]) eq 'ARRAY';
                 });

sub _build_schema {
    my $self = shift;
    my $files = File::Spec->catfile($self->schema_dir, '*.xsd');
    my $schema = XML::Compile::Schema->new([glob $files]);
    my $write  = $schema->compile(WRITER => 'AmazonEnvelope');
    return $write;
}

=head1 METHODS

=head2 product_feed

Return a string with the product XML.

The Product feed contains descriptive information about the products
in your catalog. This information allows Amazon to build a record and
assign a unique identifier known as an ASIN (Amazon Standard Item
Number) to each product. This feed is always the first step in
submitting products to Amazon because it establishes the mapping
between the seller's unique identifier (SKU) and Amazon's unique
identifier (ASIN).

=cut

sub product_feed {
    my $self = shift;
    my $data = {
                Header => {
                           MerchantIdentifier => $self->merchant_id,
                           DocumentVersion => "1.1", # unclear
                          },
                MessageType => 'Product',
                # MarketplaceName => "example",
                # PurgeAndReplace => "false", unclear if "false" works
               };

    my @messages;
    my @products = @{ $self->products };
    for (my $i = 0; $i < @products; $i++) {
        push @messages, {
                         MessageID => $i + 1,
                         OperationType => 'Update',
                         # here will crash if the object is not the one required.
                         Product => $products[$i]->as_hash,
                        };
    }
    $data->{Message} = \@messages;
    return $self->_write_out($data);
}

sub _write_out {
    my ($self, $data) = @_;
    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $xml = $self->schema->($doc, $data);
    $doc->setDocumentElement($xml);
    return $doc->toString(1);
}


1;


