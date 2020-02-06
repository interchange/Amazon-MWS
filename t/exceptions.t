#!perl

use utf8;
use strict;
use warnings;
use Test::More;
use Amazon::MWS::Exception;
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




sub handle_exception {
    my $err = shift;
    my $err_string;
    # same handling as in safe_api_call
    diag "$err";
    if ($err->can('xml')) {
        # includes the throttled and the response. This is the most common
        $err_string = $err->xml;
    } elsif ($err->isa('Amazon::MWS::Exception::Transport')) {
        $err_string = sprintf("Request:\n%s\nResponse: %s", $err->request->as_string, $err->response->as_string);
    } elsif ($err->isa('Amazon::MWS::Exception::MissingArgument')) {
        $err_string = "Missing argument " . $err->name;
    } elsif ($err->isa('Amazon::MWS::Exception::Invalid')) {
        $err_string = sprintf("Invalid field %s %s (%s)", $err->field, $err->value, $err->message);
    } elsif ($err->isa('Amazon::MWS::Exception::BadChecksum')) {
        $err_string = sprintf("Bad checksum in %s", $err->request->as_string);
    }
    ok $err_string, "Found err: $err_string";
}


done_testing;

