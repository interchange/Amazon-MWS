#!perl
use strict;
use warnings;
use utf8;

use Amazon::MWS::Uploader;
use Test::More;
use Data::Dumper;
use File::Spec;

if (-d 'schemas') {
    plan tests => 2;
}
else {
    plan skip_all => q{Missing "schemas" directory with the xsd from Amazon, skipping feeds tests};
}

my %constructor = (
                   merchant_id => '__MERCHANT_ID__',
                   access_key_id => '12341234',
                   secret_key => '123412341234',
                   marketplace_id => '123412341234',
                   endpoint => 'https://mws-eu.amazonservices.com',
                   schema_dir => 'schemas',
                   feed_dir => File::Spec->catdir(qw/t feeds/),
                  );
my $uploader = Amazon::MWS::Uploader->new(%constructor);

ok($uploader);

my $xml = <<'AMAZONXML';
<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">
  <Header>
    <DocumentVersion>1.01</DocumentVersion>
      <MerchantIdentifier>XXXXX_666666666</MerchantIdentifier>
  </Header>
  <MessageType>OrderReport</MessageType>
<Message>
    <MessageID>1</MessageID>
    <OrderReport>
        <AmazonOrderID>028-1111111-1111111</AmazonOrderID>
        <AmazonSessionID>028-2222222-2222222</AmazonSessionID>
        <OrderDate>2015-03-24T13:59:43+00:00</OrderDate>
        <OrderPostedDate>2015-03-24T13:59:43+00:00</OrderPostedDate>
        <BillingData>
            <BuyerEmailAddress>asdfalklkasdfdh@marketplace.amazon.de</BuyerEmailAddress>
            <BuyerName>Pinco Pallino</BuyerName>
            <BuyerPhoneNumber>07777777777</BuyerPhoneNumber>
            <Address>
                <Name>Pinco Pallino</Name>
                <AddressFieldOne>Via del Piff 3</AddressFieldOne>
                <City>Trieste</City>
                <StateOrRegion>FVG</StateOrRegion>
                <PostalCode>34100</PostalCode>
                <CountryCode>IT</CountryCode>
                <PhoneNumber>07777777777</PhoneNumber>
            </Address>
        </BillingData>
        <FulfillmentData>
            <FulfillmentMethod>Ship</FulfillmentMethod>
            <FulfillmentServiceLevel>Standard</FulfillmentServiceLevel>
            <Address>
                <Name>Pinco Pallino</Name>
                <AddressFieldOne>Via del Piff 3</AddressFieldOne>
                <City>Trieste</City>
                <StateOrRegion>FVG</StateOrRegion>
                <PostalCode>34120</PostalCode>
                <CountryCode>IT</CountryCode>
                <PhoneNumber>07777777777</PhoneNumber>
            </Address>
        </FulfillmentData>
        <Item>
            <AmazonOrderItemCode>46666666666666</AmazonOrderItemCode>
            <SKU>17326</SKU>
            <Title>A test item nobody cares about</Title>
            <Quantity>1</Quantity>
            <ProductTaxCode>PTC_PRODUCT_TAXABLE_A</ProductTaxCode>
            <ItemPrice>
               <Component>
                  <Type>Principal</Type>
                  <Amount currency="EUR">17.55</Amount>
               </Component>
               <Component>
                  <Type>Shipping</Type>
                  <Amount currency="EUR">0.00</Amount>
               </Component>
               <Component>
                  <Type>Tax</Type>
                  <Amount currency="EUR">0.00</Amount>
               </Component>
               <Component>
                  <Type>ShippingTax</Type>
                  <Amount currency="EUR">0.00</Amount>
               </Component>
            </ItemPrice>
            <ItemFees>
               <Fee>
                  <Type>Commission</Type>
                  <Amount currency="EUR">-2.11</Amount>
               </Fee>
            </ItemFees>
         </Item>
    </OrderReport>
</Message>
</AmazonEnvelope>

AMAZONXML


my $xml_doc = <<'AMAZONXML';
<?xml version="1.0" encoding="UTF-8" ?>
<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">
  <Header>
    <DocumentVersion>1.01</DocumentVersion>
    <MerchantIdentifier>M_IDENTIFIER</MerchantIdentifier>
  </Header>
  <MessageType>OrderReport</MessageType>
  <Message>
    <MessageID>1</MessageID>
    <OrderReport>
      <AmazonOrderID>104-2391705-5555555</AmazonOrderID>
      <AmazonSessionID>104-2391705-5555555</AmazonSessionID>
      <OrderDate>2008-12-30T08:23:23-08:00</OrderDate>
      <OrderPostedDate>2008-12-30T08:23:23-08:00</OrderPostedDate>
      <BillingData>
        <BuyerEmailAddress>testmerchant@gmail.com</BuyerEmailAddress>
        <BuyerName>ABC Limited</BuyerName>
        <BuyerPhoneNumber>407-9999999</BuyerPhoneNumber>
      </BillingData>
      <FulfillmentData>
        <FulfillmentMethod>Ship</FulfillmentMethod>
        <FulfillmentServiceLevel>Standard</FulfillmentServiceLevel>
        <Address>
          <Name>John Doe</Name>
          <AddressFieldOne>John Doe</AddressFieldOne>
          <AddressFieldTwo>4270 Cedar Ave</AddressFieldTwo>
          <City>SUMNER PARK</City>
          <StateOrRegion>FL</StateOrRegion>
          <PostalCode>32091</PostalCode>
          <CountryCode>US</CountryCode>
          <PhoneNumber>407-9999999</PhoneNumber>
        </Address>
      </FulfillmentData>
      <Item>
        <AmazonOrderItemCode>55995643055555</AmazonOrderItemCode>
        <SKU>414070</SKU>
        <Title>Nike Women's Air Pegasus+ 25 ESC Running Shoe (Anthracite/ Grey/ Neutral Grey/ Mandarin) 9</Title>
        <Quantity>1</Quantity>
        <ProductTaxCode>A_GEN_TAX</ProductTaxCode>
        <ItemPrice>
          <Component>
            <Type>Principal</Type>
            <Amount currency="USD">63.99</Amount>
          </Component>
          <Component>
            <Type>Shipping</Type>
            <Amount currency="USD">0.00</Amount>
          </Component>
          <Component>
            <Type>Tax</Type>
            <Amount currency="USD">0.00</Amount>
          </Component>
          <Component>
            <Type>ShippingTax</Type>
            <Amount currency="USD">0.00</Amount>
          </Component>
        </ItemPrice>
        <ItemFees>
          <Fee>
            <Type>Commission</Type>
            <Amount currency="USD">-9.60</Amount>
          </Fee>
        </ItemFees>
        <ItemTaxData>
          <TaxJurisdictions>
            <TaxLocationCode>100951788</TaxLocationCode>
            <City>SUMNER</City>
            <County>BROWARD</County>
            <State>FL</State>
          </TaxJurisdictions>
          <TaxableAmounts>
            <District currency="USD">0.00</District>
            <City currency="USD">0.00</City>
            <County currency="USD">0.00</County>
            <State currency="USD">0.00</State>
          </TaxableAmounts>
          <NonTaxableAmounts>
            <District currency="USD">0.00</District>
            <City currency="USD">0.00</City>
            <County currency="USD">63.99</County>
            <State currency="USD">63.99</State>
          </NonTaxableAmounts>
          <ZeroRatedAmounts>
            <District currency="USD">63.99</District>
            <City currency="USD">63.99</City>
            <County currency="USD">0.00</County>
            <State currency="USD">0.00</State>
          </ZeroRatedAmounts>
          <TaxCollectedAmounts>
            <District currency="USD">0.00</District>
            <City currency="USD">0.00</City>
            <County currency="USD">0.00</County>
            <State currency="USD">0.00</State>
          </TaxCollectedAmounts>
          <TaxRates>
            <District>0.0000</District>
            <City>0.0000</City>
            <County>0.0000</County>
            <State>0.0000</State>
          </TaxRates>
        </ItemTaxData>
        <Promotion>
          <PromotionClaimCode>_SITE_WIDE_</PromotionClaimCode>
          <MerchantPromotionID>FREESHIPPINGOVER25</MerchantPromotionID>
          <Component>
            <Type>Principal</Type>
            <Amount currency="USD">0.00</Amount>
          </Component>
          <Component>
            <Type>Shipping</Type>
            <Amount currency="USD">0.00</Amount>
          </Component>
        </Promotion>
      </Item>
    </OrderReport>
  </Message>
</AmazonEnvelope>
AMAZONXML

my @orders = ($uploader->_parse_order_reports_xml($xml), $uploader->_parse_order_reports_xml($xml_doc));

ok(@orders == 2, "Got the orders");
