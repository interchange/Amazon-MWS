package Amazon::MWS::XML::Address;

use strict;
use warnings;

use Moo;

=head1 NAME

Amazon::MWS::XML::Address

=head1 ACCESSORS

=over 4

=item Name

Name of customer for this address.

=item AddressLine1
=item AddressFieldOne
=item address1

This is a field where Amazon stores the company name, or the c/o, or
postal boxes, etc. It appears as the first line of the address, but
you can't be sure what exactly it is (save you don't want to lose it).

Sometimes the street address is here, sometimes is empty.

=item AddressLine2
=item AddressFieldTwo
=item address2

This appears to be the regular street/number address line, sometimes.
Sometimes is in the address1. You just can't know, so you have to use
some euristics, like checking if they are both set, otherwise choosing
the first available to use as street address.

=item PostalCode

Postal code for this address.

=item City

City for this address.

=item Phone
=item PhoneNumber

Phone number for this address.

=back

=cut


has Phone => (is => 'ro');
has PhoneNumber => (is => 'ro');
has PostalCode => (is => 'ro');
has AddressLine1 => (is => 'ro');
has AddressFieldOne => (is => 'ro');
has AddressLine2 => (is => 'ro');
has AddressFieldTwo => (is => 'ro');
has StateOrRegion => (is => 'ro');
has City => (is => 'ro');
has Name => (is => 'ro');
has CountryCode => (is => 'ro');

sub name {
    return shift->Name;
}

sub address1 {
    my $self = shift;
    return $self->AddressLine1 || $self->AddressFieldOne || '';
}

sub address2 {
    my $self = shift;
    return $self->AddressLine2 || $self->AddressFieldTwo || '';
}


sub address_line {
    my $self = shift;
    my $line = $self->address1;
    if (my $second = $self->address2) {
        if ($second ne $line) {
            $line .= "\n" . $second;
        }
    }
    return $line;
}

sub city {
    return shift->City;
}

sub zip {
    return shift->PostalCode;
}

sub country {
    return shift->CountryCode;
}

sub phone {
    my $self = shift;
    my $phone = $self->Phone || $self->PhoneNumber || '';
    if (ref($phone) eq 'ARRAY') {
        return join(' ', map { $_->{_} } @$phone);
    }
    else {
        return $phone;
    }
}

sub region {
    return shift->StateOrRegion;
}

sub state {
    return shift->StateOrRegion;
}

1;
