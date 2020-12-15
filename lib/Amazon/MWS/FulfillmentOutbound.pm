package Amazon::MWS::FulfillmentOutbound;

=head1 NAME

Amazon::MWS::FulfillmentOutbound - API fulfillment outbound shipment methods for Amazon Marketplace Web Services.

=head2 API methods

=over 4

=item GetServiceStatus

=back

=cut

use Amazon::MWS::Routines qw(:all);

my $fulfillment_service = '/FulfillmentOutboundShipment/2010-10-01/';

define_api_method GetServiceStatus =>
    version => '2010-10-01',
    raw_body => 0,
    service => "$fulfillment_service",
    module_name => 'Amazon::MWS::FulfillmentOutbound',
    parameters => {},
    respond => sub {
        my $root = shift;
        return $root->{Status};
   };

1;
