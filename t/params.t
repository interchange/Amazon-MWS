use warnings;
use strict;

use Test::More;

use Amazon::MWS::Routines qw(process_params);
use DateTime;

subtest 'basic types' => sub {
  my $params = {
    DateTime      => { type => 'datetime' },
    MoreThanOne   => { type => 'nonNegativeInteger' },
    ABoolFlag     => { type => 'boolean' },
    String        => { type => 'string' }
  };

  my $args;
  $args = { MoreThanOne => -5 };
  is_deeply { process_params($params, $args) }, {
    MoreThanOne => 1
  }, 'changed non-negative integer to 1';

  $args = { ABoolFlag => 9001 };
  is_deeply { process_params($params, $args) }, {
    ABoolFlag => 'true'
  }, 'changed truthy to true';

  $args = { ABoolFlag => 0 };
  is_deeply { process_params($params, $args) }, {
    ABoolFlag => 'false'
  }, 'changed falsy to false';

  my $time = DateTime->new(year => 2020, month => 1, day => 1);

  $args = { DateTime => $time };
  is_deeply { process_params($params, $args) }, {
    DateTime => '2020-01-01T00:00:00'
  }, 'properly formats a timestamp';

};

subtest 'List types' => sub {
  my $params = { MarketplaceId => { type => 'IdList' } };
  my $first = { MarketplaceId => [ qw( a b c d ) ] };
  is_deeply { process_params($params, $first) }, {
    'MarketplaceId.Id.1' => 'a',
    'MarketplaceId.Id.2' => 'b',
    'MarketplaceId.Id.3' => 'c',
    'MarketplaceId.Id.4' => 'd',
  }, 'did List type';
};


subtest 'Enum types' => sub {
  my $params = {
    Color => {
      type => 'List',
      values => [ qw(red orange yellow) ]
    }
  };
  my $first = { Color => 'yellow' };
  is_deeply { process_params $params, $first }, {
    Color => 'yellow'
  }, 'did enum type';
};








done_testing;
