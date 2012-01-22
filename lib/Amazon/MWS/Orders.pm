package Amazon::MWS::Orders;

use Amazon::MWS::Routines qw(:all);

my $orders_service = '/Orders/2011-01-01';

define_api_method ListOrders =>
    raw_body => 1,
    service => "$orders_service",
    parameters => {
        MarketplaceId => {
             required   =>      1,
             type       =>      'IdList',
        },
        OrderStatus             => { type => 'StatusList' },
        CreatedAfter            => { type => 'datetime' },
        CreatedBefore           => { type => 'datetime' },
        LastUpdatedAfter        => { type => 'datetime' },
        LastUpdatedBefore       => { type => 'datetime' }
    };

define_api_method ListOrdersByNextToken =>
    raw_body => 1,
    service => "$orders_service",
    parameters => {
       NextToken => {
            type     => 'string',
            required => 1,
        },
    };

define_api_method GetOrder =>
    raw_body => 1,
    service => "$orders_service",
    parameters => {
	AmazonOrderId => {
             required   =>      1,
             type       =>      'IdList',
        },
   };

define_api_method ListOrderItems =>
    raw_body => 1,
    service => "$orders_service",
    parameters => {
        AmazonOrderId => {
             required   =>      1,
             type       =>      'string',
        },
    };

define_api_method ListOrderItemsByNextToken =>
    raw_body => 1,
    service => "$orders_service",
    parameters => {
       NextToken => {
            type     => 'string',
            required => 1,
        },
    };

