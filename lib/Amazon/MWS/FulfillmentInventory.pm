package Amazon::MWS::FulfillmentInventory;

=head1 NAME

Amazon::MWS::Routes - API fulfillment inventory methods for Amazon Marketplace Web Services.

=head1 API methods

=head2 ListInventorySupply

=head2 ListInventorySupplyByNextToken

=cut

use Amazon::MWS::Routines qw(:all);

my $fulfillment_service = '/FulfillmentInventory/2010-10-01/';

=head1 NAME

Amazon::MWS::FulfillmentInventory - API methods for finances

=head1 API methods

=over 4

=back

=head1 Authors

=over 4

=item Eric Ferguson

=item Stefan Hornburg (Racke)

=back

=head1 License

This is free software; you can redistribute it and/or modify it under the same terms
as the Perl 5 programming language system itself.

=cut

define_api_method GetServiceStatus =>
    version => '2010-10-01',
    raw_body => 0,
    service => "$fulfillment_service",
    module_name => 'Amazon::MWS::FulfillmentInventory',
    parameters => {},
    respond => sub {
        my $root = shift;
        return $root->{Status};
   };

define_api_method ListInventorySupply =>
    raw_body => 1,
    version => '2010-10-01',
    service => "$fulfillment_service",
    parameters => {
        SellerSkus      => {
             type       => 'MemberList'
        },
        QueryStartDateTime      => { type => 'datetime' },
        ResponseGroup           => { type => 'List', values=>['Basic','Detailed'] }
    };

define_api_method ListInventorySupplyByNextToken =>
    raw_body => 1,
    version => '2010-10-01',
    service => "$fulfillment_service",
    parameters => {
        NextToken => {
            type     => 'string',
            required => 1,
        },
    };


1;
