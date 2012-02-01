package Amazon::MWS::Products;

use Amazon::MWS::Routines qw(:all);

my $products_service = '/Products/2011-10-01/';

define_api_method "GetServiceStatus" =>
    raw_body => 0,
    service => "$products_service",
    module_name => 'Amazon::MWS::Products',
    parameters => {},
    respond => sub {
        my $root = shift;
        return $root->{Status};
   };

define_api_method ListMatchingProducts =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        Query      => {
             type       => 'sttring',
             required   => 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
    };

define_api_method GetMatchingProduct =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        ASINList      => {
             type       => 'ASINList',
             required   => 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
    };

define_api_method GetLowestOfferListingsForSKU =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        SellerSKUList      => {
             type       => 'SellerSKUList',
	     required	=> 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
        ItemCondition   => { type => 'List', values=>['Any', 'New', 'Used', 'Collectible', 'Refurbished', 'Club'], required=>1 }
    };

define_api_method GetLowestOfferListingsForASIN =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        ASINList      => {
             type       => 'ASINList',
             required   => 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
        ItemCondition   => { type => 'List', values=>['Any', 'New', 'Used', 'Collectible', 'Refurbished', 'Club'], required=>1 }
    };

define_api_method GetCompetitivePricingForSKU =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        SellerSKUList      => {
             type       => 'SellerSKUList',
	     required	=> 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
    };

define_api_method GetCompetitivePricingForASIN =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        ASINList      => {
             type       => 'ASINList',
             required   => 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
    };

define_api_method GetProductCategoriesForSKU =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        SellerSKU      => {
             type       => 'string',
	     required	=> 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
    };

define_api_method GetProductCategoriesForASIN =>
    raw_body => 1,
    service => "$products_service",
    parameters => {
        ASIN      => {
             type       => 'string',
             required   => 1
        },
        MarketplaceId   => { type => 'string', required=>1 },
    };


1;
