#!perl

use utf8;
use strict;
use warnings;
use Test::More;
use Amazon::MWS::TAB::Response::FeedSubmissionResult;
use Data::Dumper;

my $text = <<'EOF';
Feed Processing Summary:
	Number of records processed		1
	Number of records successful		0

original-record-number	sku	error-code	error-type	error-message
1		79517	Error	Order Id N/A is invalid or shipment has not yet been dispatched.
EOF

my $res = Amazon::MWS::TAB::Response::FeedSubmissionResult->new(text => $text);

ok !$res->is_success;
ok $res->report_errors;
diag Dumper([ $res->report_errors ]);
ok $res->report_errors;
ok $res->errors;

done_testing;
