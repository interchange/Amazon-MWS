#!perl

use utf8;
use strict;
use warnings;
use Test::More tests => 2;
use Amazon::MWS::XML::ShippedOrder;
use DateTime;


my %shipped = (
               # amazon_order_id => '12341234',
               merchant_order_id => '8888888',
               merchant_fulfillment_id => '666666', # optional
               fulfillment_date => DateTime->new(
                                                 year => 2014,
                                                 month => 11,
                                                 day => 14,
                                                 hour => 11,
                                                 minute => 11,
                                                 second => 0,
                                                 time_zone => 'Europe/Berlin',
                                                ),
               carrier => 'UPS',
               shipping_method => 'Second Day',
               shipping_tracking_number => '123412341234',
               items => [
                         {
                          # amazon_order_item_code => '1111',
                          merchant_order_item_code => '2222',
                          merchant_fulfillment_item_id => '3333',
                          quantity => 2,
                         },
                         {
                          # amazon_order_item_code => '4444',
                          merchant_order_item_code => '5555',
                          merchant_fulfillment_item_id => '6666',
                          quantity => 3,
                         }
                        ],
              );

my $shipped_order = Amazon::MWS::XML::ShippedOrder->new(%shipped);

ok($shipped_order, "constructor validates");

is_deeply($shipped_order->as_shipping_confirmation_hashref,
          {
           MerchantOrderID => 8888888,
           MerchantFulfillmentID => '666666',
           FulfillmentDate => '2014-11-14T11:11:00+01:00',
           FulfillmentData => {
                               CarrierCode => 'UPS',
                               ShippingMethod => 'Second Day',
                               ShipperTrackingNumber => '123412341234',
                              },
           Item => [
                    {
                     MerchantOrderItemID => '2222',
                     MerchantFulfillmentItemID => '3333',
                     Quantity => 2,
                    },
                    {
                     MerchantOrderItemID => '5555',
                     MerchantFulfillmentItemID => '6666',
                     Quantity => 3,
                    },
                   ],

          },
          "Structure appears ok");

