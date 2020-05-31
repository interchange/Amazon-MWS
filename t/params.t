use warnings;
use strict;

use Test::More;

use Amazon::MWS::Routines qw(process_params);

subtest 'basic types' => sub {
  my $params = {
    CreatedAfter      => { type => 'datetime' },
    MaxResultsPerPage => { type => 'nonNegativeInteger' },
    ABoolFlag         => { type => 'boolean' },
    FooBar            => { type => 'string' }
  };

  my $first = { MaxResultsPerPage => 9001 };
  is_deeply { process_params($params, $first) }, {
    MaxResultsPerPage => 9001
  }, 'did non-negative integer';

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
