package Amazon::MWS::AmazonPay;

use Amazon::MWS::Routines qw(:all);

my $version = '2013-01-01';

=head1 NAME

Amazon::MWS::AmazonPay - API methods for Amazon Pay

=head1 API methods

=over 4

=item GetOrderReferenceDetails

=item SetOrderAttributes

=item SetOrderReferenceDetails

=item ConfirmOrderReference

=item CancelOrderReference

=item Authorize

=item GetAuthorizationDetails

=item CloseOrderReference

=back

=head1 Authors

=over 4

=item Marco Pessotto

=item Stefan Hornburg (Racke)

=back

=head1 License

This is free software; you can redistribute it and/or modify it under the same terms
as the Perl 5 programming language system itself.

=cut

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

define_api_method(CancelOrderReference =>
                  version => $version,
                  parameters => {
                                 AmazonOrderReferenceId => {
                                                            required => 1,
                                                            type => 'string',
                                                           },
                                 CancelationReason => { type => 'string' },
                                },
                  respond => sub { return shift },
                 );

define_api_method(Authorize =>
                  version => $version,
                  parameters => {
                                 AmazonOrderReferenceId => {
                                                            required => 1,
                                                            type => 'string',
                                                           },
                                 # defined by caller, must be unique, max 32 chars
                                 AuthorizationReferenceId => {
                                                              required => 1,
                                                              type => 'string',
                                                             },
                                 'AuthorizationAmount.Amount' => {
                                                                  type => 'string',
                                                                  required => 1,
                                                                 },
                                 'AuthorizationAmount.CurrencyCode' => {
                                                                        type => 'string',
                                                                        required => 1,
                                                                       },
                                 # max 255
                                 SellerAuthorizationNote => { type => 'string' },
                                 # minutes. set to 0 for synchronous
                                 TransactionTimeout => { type => 'integer' },
                                 CaptureNow => { type => 'boolean' },
                                 # max char.
                                 SoftDescriptor => { type => 'string' },
                                },
                  respond => sub { return shift->{AuthorizationDetails} }
                 );

define_api_method(GetAuthorizationDetails =>
                  version => $version,
                  parameters => {
                                 AmazonAuthorizationId => {
                                                           required => 1,
                                                           type => 'string',
                                                          },
                                },
                  respond => sub { return shift->{AuthorizationDetails} }
                 );

define_api_method(CloseOrderReference =>
                  version => $version,
                  parameters => {
                                 AmazonOrderReferenceId => {
                                                            required => 1,
                                                            type => 'string',
                                                           },
                                 ClosureReason => { type => 'string' },
                                },
                  respond => sub { return shift });
1;
