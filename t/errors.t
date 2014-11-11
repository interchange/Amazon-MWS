#!perl

use strict;
use warnings;
use Amazon::MWS::XML::Response::FeedSubmissionResult;
use Test::More;

if (-d 'schemas') {
    plan tests => 4;
}
else {
    plan skip_all => q{Missing "schemas" directory with the xsd from Amazon, skipping feeds tests};
}


my $xml = <<'XML';
<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">
        <Header>
                <DocumentVersion>1.02</DocumentVersion>
                <MerchantIdentifier>_MERCHANT_ID_</MerchantIdentifier>
        </Header>
        <MessageType>ProcessingReport</MessageType>
        <Message>
                <MessageID>1</MessageID>
                <ProcessingReport>
                        <DocumentTransactionID>123412341234</DocumentTransactionID>
                        <StatusCode>Complete</StatusCode>
                        <ProcessingSummary>
                                <MessagesProcessed>7</MessagesProcessed>
                                <MessagesSuccessful>1</MessagesSuccessful>
                                <MessagesWithError>6</MessagesWithError>
                                <MessagesWithWarning>0</MessagesWithWarning>
                        </ProcessingSummary>
                        <Result>
                                <MessageID>1</MessageID>
                                <ResultCode>Error</ResultCode>
                                <ResultMessageCode>6024</ResultMessageCode>
                                <ResultDescription>Seller is not authorized to list products by this brand name in this product line or category. For more details, see http://sellercentral.amazon.de/gp/errorcode/6024</ResultDescription>
                                <AdditionalInfo>
                                        <SKU>16414</SKU>
                                </AdditionalInfo>
                        </Result>
                        <Result>
                                <MessageID>2</MessageID>
                                <ResultCode>Error</ResultCode>
                                <ResultMessageCode>6024</ResultMessageCode>
                                <ResultDescription>Seller is not authorized to list products by this brand name in this product line or category. For more details, see http://sellercentral.amazon.de/gp/errorcode/6024</ResultDescription>
                                <AdditionalInfo>
                                        <SKU>12110</SKU>
                                </AdditionalInfo>
                        </Result>
                        <Result>
                                <MessageID>3</MessageID>
                                <ResultCode>Error</ResultCode>
                                <ResultMessageCode>6024</ResultMessageCode>
                                <ResultDescription>Seller is not authorized to list products by this brand name in this product line or category. For more details, see http://sellercentral.amazon.de/gp/errorcode/6024</ResultDescription>
                                <AdditionalInfo>
                                        <SKU>12112</SKU>
                                </AdditionalInfo>
                        </Result>
                        <Result>
                                <MessageID>4</MessageID>
                                <ResultCode>Error</ResultCode>
                                <ResultMessageCode>6024</ResultMessageCode>
                                <ResultDescription>Seller is not authorized to list products by this brand name in this product line or category. For more details, see http://sellercentral.amazon.de/gp/errorcode/6024</ResultDescription>
                                <AdditionalInfo>
                                        <SKU>14742</SKU>
                                </AdditionalInfo>
                        </Result>
                        <Result>
                                <MessageID>6</MessageID>
                                <ResultCode>Error</ResultCode>
                                <ResultMessageCode>6024</ResultMessageCode>
                                <ResultDescription>Seller is not authorized to list products by this brand name in this product line or category. For more details, see http://sellercentral.amazon.de/gp/errorcode/6024</ResultDescription>
                                <AdditionalInfo>
                                        <SKU>12194</SKU>
                                </AdditionalInfo>
                        </Result>
                        <Result>
                                <MessageID>7</MessageID>
                                <ResultCode>Error</ResultCode>
                                <ResultMessageCode>6024</ResultMessageCode>
                                <ResultDescription>Seller is not authorized to list products by this brand name in this product line or category. For more details, see http://sellercentral.amazon.de/gp/errorcode/6024</ResultDescription>
                                <AdditionalInfo>
                                        <SKU>16415</SKU>
                                </AdditionalInfo>
                        </Result>
                </ProcessingReport>
        </Message>
</AmazonEnvelope> 
XML

my $result = Amazon::MWS::XML::Response::FeedSubmissionResult->new(xml => $xml,
                                                                   schema_dir => 'schemas',
                                                                  );

ok($result);
ok(!$result->is_success);
ok($result->errors) and diag $result->errors;
is_deeply([ $result->failed_skus ], [qw/16414 12110 12112 14742 12194 16415/]);

