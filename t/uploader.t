#!perl

use strict;
use warnings;
use Amazon::MWS::Uploader;
use Test::More;

my $feed_dir = 't/feeds';

if (-d 'schemas') {
    plan tests => 3;
}
else {
    plan skip_all => q{Missing "schemas" directory with the xsd from Amazon, skipping feeds tests};
}



unless (-d $feed_dir) {
    mkdir $feed_dir or die "Cannot create $feed_dir $!";
}

my %constructor = (
                   merchant_id => '__MERCHANT_ID__',
                   access_key_id => '12341234',
                   secret_key => '123412341234',
                   marketplace_id => '123412341234',
                   endpoint => 'https://mws-eu.amazonservices.com',
                   feed_dir => $feed_dir,
                   schema_dir => 'schemas',
                  );

my $uploader = Amazon::MWS::Uploader->new(%constructor);

ok($uploader);
is($uploader->_unique_shop_id, $constructor{merchant_id});
$uploader = Amazon::MWS::Uploader->new(%constructor,
                                       shop_id => 'shoppe');

is($uploader->_unique_shop_id, 'shoppe');



