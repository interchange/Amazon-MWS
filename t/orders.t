#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

use Amazon::MWS::XML::Order;

my $order_data = {
                  'NumberOfItemsUnshipped' => '0',
                  'PaymentMethod' => 'Other',
                  'ShipmentServiceLevelCategory' => 'Standard',
                  'LatestShipDate' => '2014-10-28T22:59:59Z',
                  'OrderTotal' => {
                                   'Amount' => '119.80',
                                   'CurrencyCode' => 'EUR'
                                  },
                  'ShippedByAmazonTFM' => 'false',
                  'SalesChannel' => 'Amazon.de',
                  'LastUpdateDate' => '2014-10-27T09:38:56Z',
                  'NumberOfItemsShipped' => '2',
                  'PurchaseDate' => '2014-10-26T04:40:40Z',
                  'AmazonOrderId' => '333-9999999-99999999',
                  'ShipServiceLevel' => 'Std DE Dom',
                  'BuyerEmail' => 'xxxxxxxxxxxxx@marketplace.amazon.de',
                  'ShippingAddress' => {
                                        'StateOrRegion' => 'Berlin',
                                        'CountryCode' => 'DE',
                                        'PostalCode' => '11111',
                                        'AddressLine2' => 'Strazze',
                                        'Name' => "John Doe",
                                        'City' => 'Berlin'
                                       },
                  'BuyerName' => "John Doe",
                  'EarliestDeliveryDate' => '2014-10-27T23:00:00Z',
                  'EarliestShipDate' => '2014-10-26T23:00:00Z',
                  'FulfillmentChannel' => 'MFN',
                  'OrderType' => 'StandardOrder',
                  'MarketplaceId' => 'MARKETPLACE-ID',
                  'LatestDeliveryDate' => '2014-10-31T22:59:59Z',
                  'OrderStatus' => 'Shipped'
                 };
my $orderline_data = [
                      {
                       'ShippingPrice' => {
                                           'Amount' => '0.00',
                                           'CurrencyCode' => 'EUR'
                                          },
                       'GiftWrapPrice' => {
                                           'CurrencyCode' => 'EUR',
                                           'Amount' => '0.00'
                                          },
                       'PromotionDiscount' => {
                                               'CurrencyCode' => 'EUR',
                                               'Amount' => '0.00'
                                              },
                       'ConditionId' => 'New',
                       'ItemPrice' => {
                                       'CurrencyCode' => 'EUR',
                                       'Amount' => '119.80'
                                      },
                       'ShippingTax' => {
                                         'Amount' => '0.00',
                                         'CurrencyCode' => 'EUR'
                                        },
                       'ShippingDiscount' => {
                                              'CurrencyCode' => 'EUR',
                                              'Amount' => '0.00'
                                             },
                       'OrderItemId' => '999999999999999',
                       'Title' => "Blablablablba",
                       'SellerSKU' => '9999999',
                       'ItemTax' => {
                                     'Amount' => '0.00',
                                     'CurrencyCode' => 'EUR'
                                    },
                       'QuantityOrdered' => '2',
                       'ConditionSubtypeId' => 'New',
                       'ASIN' => 'AAAAAAAAA',
                       'GiftWrapTax' => {
                                         'Amount' => '0.00',
                                         'CurrencyCode' => 'EUR'
                                        },
                       'QuantityShipped' => '2'
                      }
                     ];

my $order = Amazon::MWS::XML::Order->new(order => $order_data,
                                         orderline => $orderline_data);

is($order->subtotal, "119.80");
my @items = $order->items;
is($items[0]->price, "59.90");
ok ($order->order_is_shipped, "It is shipped");
