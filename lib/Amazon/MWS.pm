package Amazon::MWS;

=head1 NAME

Amazon::MWS - Perl interface to Amazon Marketplace Web Services

=head1 VERSION

0.111

=cut

our $VERSION = '0.111';

=head1 DESCRIPTION

See L<Amazon::MWS::Client>

=head1 MWS in practice

=head2 Product price

Every product uploaded needs a price of 0.01 or higher, otherwise you
get the following error:

    0.00 price (standard or sales) will not be accepted.
    Please ensure that every SKU in your feed has a price at least equal to or greater than 0.01

=head2 Shipping costs

You need to configure the shipping costs in Amazon Seller Central, you can't pass them
through MWS:

L<https://sellercentral.amazon.com/gp/shipping/dispatch.html>

=head2 Stuck uploads

There is no guarantee that Amazon finishes your uploads at all. We had uploads
stuck for at least a week.

=head2 Multiple marketplaces

You can use this module and the uploader for multiple Amazon marketplaces.
Please make sure that you disable Amazon's synchronisation between marketplaces.

For marketplaces with a different currency you need to convert your price first.

The list of marketplaces can be found at:

L<http://docs.developer.amazonservices.com/en_US/dev_guide/DG_Endpoints.html>

=head1 Uploader Module

L<Amazon::MWS::Uploader> is an upload agent for Amazon::MWS.

=head1 XML Modules

=over 4

=item Generic Feed

L<Amazon::MWS::XML::GenericFeed>

=item Feed

L<Amazon::MWS::XML::Feed>

=item Product

L<Amazon::MWS::XML::Product>

=item Address

L<Amazon::MWS::XML::Address>

=item Order

L<Amazon::MWS::XML::Order>

=item OrderlineItem

L<Amazon::MWS::XML::OrderlineItem>

=back

=head1 AUTHORS

Paul Driver
Phil Smith
Marco Pessotto
Stefan Hornburg (Racke)

=head2 COPYRIGHT

This is free software; you can redistribute it and/or modify it under the same terms
as the Perl 5 programming language system itself.

=cut

1;
