package Amazon::MWS::AmazonPay;

use Amazon::MWS::Routines qw(:all);

my $version = '2013-01-01';

define_api_method (GetOrderReferenceDetails =>
                   version => $version,
                   parameters => {
                                  AmazonOrderReferenceId => {
                                                             required => 1,
                                                             type => 'string',
                                                            },
                                  AccessToken => {
                                                  required => 0,
                                                  type => 'string',
                                                 },
                                 },
                   respond => sub { return shift->{OrderReferenceDetails} },
                  );

define_api_method (SetOrderAttributes =>
                   version => $version,
                   parameters => {
                                  AmazonOrderReferenceId => {
                                                             required => 1,
                                                             type => 'string',
                                                            },
                                  'OrderAttributes.OrderTotal.Amount' => { type => 'string', required => 0 },
                                  'OrderAttributes.OrderTotal.CurrencyCode' => { type => 'string', required => 0 },
                                  'OrderAttributes.PlatformId' => { type => 'string', required => 0 },
                                  'OrderAttributes.SellerNote' => { type => 'string', required => 0 },
                                  'OrderAttributes.SellerOrderAttributes.SellerOrderId' => { type => 'string', required => 0 },
                                  'OrderAttributes.SellerOrderAttributes.StoreName' => { type => 'string', required => 0 },
                                  'OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderId' => { type => 'string', required => 0 },
                                  'OrderAttributes.PaymentServiceProviderAttributes.PaymentServiceProviderOrderId' => { type => 'string', required => 0 },
                                 },
                   respond => sub { return shift->{OrderReferenceDetails} },
                  );
  
define_api_method(SetOrderReferenceDetails =>
                  version => $version,
                  parameters => {
                                 AmazonOrderReferenceId => {
                                                            required => 1,
                                                            type => 'string',
                                                           },
                                 'OrderReferenceAttributes.OrderTotal.Amount' => { type => 'string', required => 0 },
                                 'OrderReferenceAttributes.OrderTotal.CurrencyCode' => { type => 'string', required => 0 },
                                 'OrderReferenceAttributes.PlatformId' => { type => 'string', required => 0 },
                                 'OrderReferenceAttributes.SellerNote' => { type => 'string', required => 0 },
                                 'OrderReferenceAttributes.SellerOrderAttributes.SellerOrderId' => { type => 'string', required => 0 },
                                 'OrderAttributes.SellerOrderAttributes.StoreName' => { type => 'string', required => 0 },
                                },
                  respond => sub { return shift->{OrderReferenceDetails} },
                 );
define_api_method(ConfirmOrderReference =>
                  version => $version,
                  parameters => {
                                 AmazonOrderReferenceId => {
                                                            required => 1,
                                                            type => 'string',
                                                           },

# these keys are not documented in
# https://developer.amazon.com/de/docs/eu/amazon-pay-api/confirmorderreference.html
# but only here:
# https://developer.amazon.com/de/docs/eu/amazon-pay-onetime/confirm-purchase.html

                                 SuccessUrl => { type => 'string' },
                                 FailureUrl => { type => 'string' },
                                },
                  # will not return anything, though
                  respond => sub { return shift },
                 );
1;
