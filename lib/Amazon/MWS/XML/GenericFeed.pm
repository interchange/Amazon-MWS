package Amazon::MWS::XML::GenericFeed;

use strict;
use warnings;
use utf8;

use XML::Compile::Schema;
use File::Spec;
use Data::Dumper;

use Moo;

=head1 NAME

Amazon::MWS::XML::Feed -- base module to create XML feeds for Amazon MWS

=head1 ACCESSORS

=head2 schema_dir

The directory with the xsd files from amazon.

=head2 schema

The L<XML::Compile::Schema> object (built lazily).

=head2 merchant_id

Required. The merchant id provided by Amazon.

=cut

has schema_dir => (is => 'ro',
                   required => 1,
                   isa => sub {
                       die "Not a dir" unless -d $_[0];
                   });

has schema => (is => 'lazy');

has debug => (is => 'rw');

has merchant_id => (is => 'ro',
                    required => 1,
                    isa => sub {
                        die "the merchant id must be a string" unless $_[0];
                    });

sub _build_schema {
    my $self = shift;
    my $files = File::Spec->catfile($self->schema_dir, '*.xsd');
    my $schema = XML::Compile::Schema->new([glob $files]);
    my $write  = $schema->compile(WRITER => 'AmazonEnvelope');
    return $write;
}

=head2 create_feed($operation, \@messages, %options)

Create a feed of type $operation, with the messages passed. The
options are not used yet.

=cut

sub create_feed {
    my ($self, $operation, $messages, %options) = @_;
    die "Missign operation" unless $operation;
    return unless $messages && @$messages;

    my $data = {
                Header => {
                           MerchantIdentifier => $self->merchant_id,
                           DocumentVersion => "1.1", # unclear
                          },
                MessageType => $operation,
                # to be handled with options eventually?
                # MarketplaceName => "example",
                # PurgeAndReplace => "false", unclear if "false" works
                Message => $messages,
               };
    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $xml = $self->schema->($doc, $data);
    $doc->setDocumentElement($xml);
    return $doc->toString(1);
}




1;
