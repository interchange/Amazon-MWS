#!perl

use utf8;
use strict;
use warnings;
use Test::More;
use Amazon::MWS::Exception;
use Amazon::MWS::Client;
use Try::Tiny;
use Scalar::Util qw/blessed/;
use HTTP::Request;
use HTTP::Response;


try {
    Amazon::MWS::Exception::MissingArgument->throw(name => "bla");
} catch {
    handle_exception($_);
};
try {
    Amazon::MWS::Exception::Invalid->throw(field => "blah", value => 'val', message => 'message');
} catch {
    handle_exception($_);
};
try {
    Amazon::MWS::Exception::Transport->throw(request => HTTP::Request->new, response => HTTP::Response->new);
} catch {
    handle_exception($_);
};
try {
    Amazon::MWS::Exception::Response->throw(xml => "<xml>");
} catch {
    handle_exception($_);
};
try {
    Amazon::MWS::Exception::Throttled->throw(xml => "<xml>");
} catch {
    handle_exception($_);
};

try {
    Amazon::MWS::Exception::BadChecksum->throw(request => HTTP::Request->new);
} catch {
    handle_exception($_);
};

try {
    Amazon::MWS::Exception->throw();
} catch {
    handle_exception($_);
};

sub handle_exception {
    my $err = shift;
    my $err_string = Amazon::MWS::Client::_stringify_exception($err);
    ok $err_string, "Found err: $err_string";
}


done_testing;

