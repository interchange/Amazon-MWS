#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

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
  
my $order = Amazon::MWS::XML::Order->new(order => $order_data,
                                         orderline => $orderline_data);

ok $order;
is $order->subtotal, '122.68';
is $order->total_cost, '160.08';
is $order->currency, 'USD';
