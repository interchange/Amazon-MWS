package Amazon::MWS::TAB::Response::FeedSubmissionResult;

use strict;
use warnings;

use Moo;

=head1 NAME

Amazon::MWS::TAB::Response::FeedSubmissionResult -- response parser for text responses

This is used only for the PDF Invoice submission at the moment, so
most of methods are not implemented.

=head1 SYNOPSIS

  return Amazon::MWS::TAB::Response->new(text => $body);

=head1 ACCESSORS

=head2 text

Required parameter with the content of the text response.

=head1 METHODS

=head2 report_errors

A list of error messages, where each element is an hashref with this keys:

=over 4

=item code (numeric)

=item type (warning or error)

=item message (human-readable)

=back

=head2 is_success

Boolean

=head2 errors

Combined error messages as a string.

=head2 skus_errors

Returns empty array.

=head2 skus_warnings

Returns empty array.

=cut

has text => (is => 'ro', required => 1);

sub skus_errors {
    return [];
}

sub skus_warnings {
    return [];
}

sub report_errors {
    my $self = shift;
    my $body = $self->text;
    my @headers;
    my @records;
    foreach my $l (split(/\r?\n/, $body)) {
        next unless $l =~ /\t/;
        if ($l =~ m/^original-record-number.*error-code.*error-message/) {
            @headers = split(/\t/, $l);
        }
        elsif (@headers) {
            my @fields =  split(/\t/, $l);
            my %rec;
            @rec{@headers} = @fields;
            if ($rec{'error-code'}) {
                push @records, {
                                code => $rec{'error-code'},
                                type => $rec{'error-type'},
                                message => $rec{'error-message'},
                               };
            }
        }
    }
    # turn them into a structure
    return @records;
}

sub is_success {
    my $self = shift;
    my @errors = $self->report_errors;
    return !@errors;
}

sub errors {
    my $self = shift;
    return join (' ', map { $_->{message} } $self->report_errors);
}


1;
