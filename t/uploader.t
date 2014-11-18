#!perl

use strict;
use warnings;
use Amazon::MWS::Uploader;
use Data::Dumper;
use Test::More;

my $feed_dir = 't/feeds';

if (-d 'schemas') {
    plan tests => 9;
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

eval {
    $uploader = Amazon::MWS::Uploader->new(%constructor,
                                           reset_errors => '! 2341 , 1234 , 1234 ,'
                                           );
};
ok (!$@, "No exception");

is_deeply($uploader->_reset_error_structure,
          {
           negate => 1,
           codes => {
                     2341 => 1,
                     1234 => 1,
                    }
          }, "reset error structure ok")
  or diag Dumper($uploader->_reset_error_structure);

eval {
    $uploader = Amazon::MWS::Uploader->new(%constructor,
                                           reset_errors => '2341 , 1234 , 1234 ,'
                                           );
};
ok (!$@, "No exception");


is_deeply($uploader->_reset_error_structure,
          {
           negate => 0,
           codes => {
                     2341 => 1,
                     1234 => 1,
                    }
          }, "reset error structure ok (no negate)")
  or diag Dumper($uploader->_reset_error_structure);



eval {
    $uploader = Amazon::MWS::Uploader->new(%constructor,
                                           reset_errors => 'balklasdfl'
                                          );
};
ok ($@, "Found exception") and diag $@;

eval {
    $uploader = Amazon::MWS::Uploader->new(%constructor,
                                           db_options => undef);
};

ok (!$@, "undef as db_options is fine") and diag $@;

