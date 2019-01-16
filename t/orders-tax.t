#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 12;

use Amazon::MWS::XML::Order;

my $order_data = {
            'AmazonOrderId' => '114-99999-99999999',
            'BuyerEmail' => 'xxxxxxxxxxxxx@marketplace.amazon.com',
            'BuyerName' => 'XXX XXXXXXX',
            'EarliestDeliveryDate' => '2018-02-20T08:00:00Z',
            'EarliestShipDate' => '2018-01-30T08:00:00Z',
            'FulfillmentChannel' => 'MFN',
            'IsBusinessOrder' => 'false',
            'IsPremiumOrder' => 'false',
            'IsPrime' => 'false',
            'IsReplacementOrder' => 'false',
            'LastUpdateDate' => '2018-01-30T05:32:26Z',
            'LatestDeliveryDate' => '2018-03-14T06:59:59Z',
            'LatestShipDate' => '2018-02-01T07:59:59Z',
            'MarketplaceId' => 'ATVPDKIKX0DER',
            'NumberOfItemsShipped' => '0',
            'NumberOfItemsUnshipped' => '1',
            'OrderStatus' => 'Unshipped',
            'OrderTotal' => {
                             'Amount' => '160.08',
                             'CurrencyCode' => 'USD'
                            },
            'OrderType' => 'StandardOrder',
            'PaymentMethod' => 'Other',
            'PaymentMethodDetails' => {
                                       'PaymentMethodDetail' => 'Standard'
                                      },
            'PurchaseDate' => '2018-01-30T04:55:50Z',
            'SalesChannel' => 'Amazon.com',
            'ShipServiceLevel' => 'Std US D2D Dom',
            'ShipmentServiceLevelCategory' => 'Standard',
            'ShippedByAmazonTFM' => 'false',
            'ShippingAddress' => {
                                  'AddressLine1' => 'CENSORED',
                                  'AddressType' => 'Residential',
                                  'City' => 'CENSORED',
                                  'CountryCode' => 'US',
                                  'Name' => 'censored',
                                  'Phone' => 'censored',
                                  'PostalCode' => '99999-8888',
                                  'StateOrRegion' => 'CA'
                                 }
           };
my $orderline_data = [
                  {
                   'ASIN' => 'B00K21G30S',
                   'ConditionId' => 'New',
                   'ConditionSubtypeId' => 'New',
                   'GiftWrapPrice' => {
                                       'Amount' => '0.00',
                                       'CurrencyCode' => 'USD'
                                      },
                   'GiftWrapTax' => {
                                     'Amount' => '0.00',
                                     'CurrencyCode' => 'USD'
                                    },
                   'IsGift' => 'false',
                   'ItemPrice' => {
                                   'Amount' => '112.45',
                                   'CurrencyCode' => 'USD'
                                  },
                   'ItemTax' => {
                                 'Amount' => '10.23',
                                 'CurrencyCode' => 'USD'
                                },
                   'OrderItemId' => '99999999999999999',
                   'ProductInfo' => {
                                     'NumberOfItems' => '1'
                                    },
                   'PromotionDiscount' => {
                                           'Amount' => '0.00',
                                           'CurrencyCode' => 'USD'
                                          },
                   'QuantityOrdered' => '1',
                   'QuantityShipped' => '0',
                   'SellerSKU' => '2210212-008530-D',
                   'ShippingDiscount' => {
                                          'Amount' => '0.00',
                                          'CurrencyCode' => 'USD'
                                         },
                   'ShippingPrice' => {
                                       'Amount' => '34.28',
                                       'CurrencyCode' => 'USD'
                                      },
                   'ShippingTax' => {
                                     'Amount' => '3.12',
                                     'CurrencyCode' => 'USD'
                                    },
                   'TaxCollection' => {
                                       'Model' => 'MarketplaceFacilitator',
                                       'ResponsibleParty' => 'Amazon Services, Inc.'
                                      },
                   'Title' => 'Heavy German Silver Ladies Dressage Spur'
                  }
                 ];
  
{
    my $order = Amazon::MWS::XML::Order->new(order => $order_data,
                                             include_tax_in_prices => 1,
                                             orderline => $orderline_data);
    ok $order;
    is $order->subtotal, '122.68';
    is $order->total_cost, '160.08';
    is $order->items_ref->[0]->shipping_tax, '3.12';
    is $order->items_ref->[0]->item_tax, '10.23';
    is $order->shipping_tax, '3.12';
    is $order->item_tax, '10.23';
    is $order->currency, 'USD';
}
{
    my $order = Amazon::MWS::XML::Order->new(order => $order_data,
                                             include_tax_in_prices => 0,
                                             orderline => $orderline_data);
    ok $order;
    eval { $order->subtotal; $order->total_cost };
    ok($@) and diag $@;
}



my $canceled = {
                            'AmazonOrderId' => '702-9999999-999999999',
                            'EarliestShipDate' => '2018-01-26T00:02:54Z',
                            'FulfillmentChannel' => 'MFN',
                            'IsBusinessOrder' => 'false',
                            'IsPremiumOrder' => 'false',
                            'IsPrime' => 'false',
                            'IsReplacementOrder' => 'false',
                            'LastUpdateDate' => '2018-01-26T00:07:06Z',
                            'LatestShipDate' => '2018-01-26T00:02:54Z',
                            'MarketplaceId' => 'A2EUQ1WTGCTBG2',
                            'NumberOfItemsShipped' => '0',
                            'NumberOfItemsUnshipped' => '0',
                            'OrderStatus' => 'Canceled',
                            'OrderType' => 'StandardOrder',
                            'PaymentMethodDetails' => {
                                                       'PaymentMethodDetail' => 'Standard'
                                                      },
                            'PurchaseDate' => '2018-01-25T00:00:00Z',
                            'SalesChannel' => 'Amazon.ca',
                            'ShipServiceLevel' => 'Exp CA D2D Dom',
                            'ShipmentServiceLevelCategory' => 'Expedited'
               };
my $canceled_orderline =  [
                                {
                                 'ASIN' => 'B0000000',
                                 'ConditionId' => 'New',
                                 'ConditionSubtypeId' => 'New',
                                 'IsGift' => 'false',
                                 'OrderItemId' => '9999999999999999',
                                 'ProductInfo' => {
                                                   'NumberOfItems' => '1'
                                                  },
                                 'QuantityOrdered' => '0',
                                 'QuantityShipped' => '0',
                                 'SellerSKU' => '1030616-007150-150',
                                 'Title' => 'Pazz - stirrup leathers Soft Touch'
                                }
                               ];

my $corder = Amazon::MWS::XML::Order->new(order => $canceled,
                                          include_tax_in_prices => 1,
                                          orderline => $canceled_orderline);
is $corder->total_cost, 0;
ok !$corder->can_be_imported;
