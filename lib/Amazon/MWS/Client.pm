package Amazon::MWS::Client;

use warnings;
use strict;

our $VERSION = '0.8';


use Amazon::MWS::TypeMap qw(:all);
use Amazon::MWS::Routines qw(:all);
use Amazon::MWS::InboundShipments;
use Amazon::MWS::Finances;
use Amazon::MWS::FulfillmentInventory;
use Amazon::MWS::FulfillmentOutbound;
use Amazon::MWS::Orders;
use Amazon::MWS::Sellers;
use Amazon::MWS::Reports;
use Amazon::MWS::Feeds;
use Amazon::MWS::Products;
use Amazon::MWS::AmazonPay;
use Try::Tiny;
use Data::Dumper;
use Scalar::Util qw/blessed/;

sub agent {
    return shift->{agent};
}

sub safe_api_call {
    my ($self, $method, @args) = @_;
    my %out = (
               response => undef,
               error => undef,
              );
    if ($self->can($method)) {
        try {
            $out{response} = $self->$method(@args);
        } catch {
            my $err = $out{error_object} = $_;
            $out{error} = _stringify_exception($err);
        };
    }
    else {
        $out{error} = "Invalid method $method";
    }
    return \%out;
}

sub _stringify_exception {
    my $err = shift;
    my $err_string;
    if (blessed($err)) {
        if ($err->can('xml')) {
            # includes the throttled and the response. This is the most common
            $err_string = sprintf("%s XML: %s", $err->description, $err->xml);
        }
        elsif ($err->isa('Amazon::MWS::Exception::Transport')) {
            $err_string = sprintf("Request:\n%s\nResponse: %s",
                                  $err->request->as_string,
                                  $err->response->as_string);
        }
        elsif ($err->isa('Amazon::MWS::Exception::MissingArgument')) {
            $err_string = "Missing argument " . $err->name;
        }
        elsif ($err->isa('Amazon::MWS::Exception::Invalid')) {
            $err_string = sprintf("Invalid field %s %s (%s)", $err->field, $err->value, $err->message);
        }
        elsif ($err->isa('Amazon::MWS::Exception::BadChecksum')) {
            $err_string = sprintf("Bad checksum in %s", $err->request->as_string);
        }
    }
    return $err_string || "$err";
}

1;

__END__

=head1 NAME

Amazon::MWS::Client

=head1 DESCRIPTION

An API binding for Amazon's Marketplace Web Services.  An overview of the
entire interface can be found at L<https://mws.amazon.com/docs/devGuide>.

=head1 METHODS

=head2 new

Constructs a new client object.  Takes the following keyword arguments:

=head3 agent_attributes

An attributes you would like to add (besides language=Perl) to the user agent
string, as a hashref.

=head3 application

The name of your application.  Defaults to 'Amazon::MWS::Client'

=head3 version

The version of your application.  Defaults to the current version of this
module.

=head3 endpoint

Where MWS lives.  Defaults to 'https://mws.amazonaws.com'.

=head3 access_key_id

Your AWS Access Key Id

=head3 secret_key

Your AWS Secret Access Key

=head3 merchant_id

Your Amazon Merchant ID

=head3 marketplace_id

The marketplace id for the calls being made by this object.

=head1 EXCEPTIONS

Any of the L<API METHODS> can throw the following exceptions
(Exception::Class).  They are all subclasses of Amazon::MWS::Exception.

=head2 Amazon::MWS::Exception::MissingArgument

The call to the API method was missing a required argument.  The name of the
missing argument can be found in $e->name.

=head2 Amazon::MWS::Exception::Transport

There was an error communicating with the Amazon endpoint.  The HTTP::Request
and Response objects can be found in $e->request and $e->response.

=head2 Amazon::MWS::Exception::Response

Amazon returned an response, but indicated an error.  An arrayref of hashrefs
corresponding to the error xml (via XML::Simple on the Error elements) is
available at $e->errors, and the entire xml response is available at $e->xml.

=head2 Amazon::MWS::Exception::BadChecksum

If Amazon sends the 'Content-MD5' header and it does not match the content,
this exception will be thrown.  The response can be found in $e->response.

=head1 INTERNAL METHODS

=head2 agent

The LWP::UserAgent object used to send the requests to Amazon.

=head1 API METHODS

The following methods may be called on objects of this class.  All concerns
(such as authentication) which are common to every request are handled by this
class.  

Enumerated values may be specified as strings or as constants from the
Amazon::MWS::Enumeration packages for compile time checking.  

All parameters to individual API methods may be specified either as name-value
pairs in the argument string or as hashrefs, and should have the same names as
specified in the API documentation.  

Return values will be hashrefs with keys as specified in the 'Response
Elements' section of the API documentation unless otherwise noted.

The mapping of API datatypes to perl datatypes is specified in
L<Amazon::MWS::TypeMap>.  Note that where the documentation calls for a
'structured list', you should pass in an arrayref.

=head2 SubmitFeed

Requires an additional 'content_type' argument specifying what content type
the HTTP-BODY is.

=head2 GetFeedSubmissionList

=head2 GetFeedSubmissionListByNextToken

=head2 GetFeedSubmissionCount

Returns the count as a simple scalar (as do all methods ending with Count)

=head2 CancelFeedSubmissions

=head2 GetFeedSubmissionResult

The raw body of the response is returned.

=head2 RequestReport

The returned ReportRequest will be an arrayref for consistency with other
methods, even though there will only ever be one element.

=head2 GetReportRequestList

=head2 GetReportRequestListByNextToken

=head2 GetReportRequestCount

=head2 CancelReportRequests

=head2 GetReportList

=head2 GetReportListByNextToken

=head2 GetReportCount

=head2 GetReport

The raw body is returned.

=head2 ManageReportSchedule

=head2 GetReportScheduleList

=head2 GetReportScheduleListByNextToken

=head2 GetReportScheduleCount

=head2 UpdateReportAcknowledgements

=head2 AmazonPay

=head3 GetOrderReferenceDetails

=head3 SetOrderAttributes

=head2 Wrapper method

=head3 safe_api_call($method_name, @arguments)

This is a convenience method which wraps the call catching the
exceptions. It returns an hashref with three keys, C<response> (with
the response, if any) and C<error> (with an error string, if any) and
C<error_object> (with the exception object which originates the error
string, if any).

=head1 AUTHOR

Paul Driver C<< frodwith@cpan.org >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Plain Black Corporation L<http://plainblack.com>.
All rights reserved

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.  See L<perlartistic>.
