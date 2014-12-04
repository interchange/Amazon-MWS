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
=item address1

This is a field where Amazon stores the company name, or the c/o, or
postal boxes, etc. It appears as the first line of the address, but
you can't be sure what exactly it is (save you don't want to lose it).

Sometimes the street address is here, sometimes is empty.

=item AddressLine2
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

Phone number for this address.

=back

=cut


has Phone => (is => 'ro');
has PostalCode => (is => 'ro');
has AddressLine1 => (is => 'ro');
has AddressLine2 => (is => 'ro');
has StateOrRegion => (is => 'ro');
has City => (is => 'ro');
has Name => (is => 'ro');
has CountryCode => (is => 'ro');

sub name {
    return shift->Name;
}

sub address1 {
    return shift->AddressLine1;
}

sub address2 {
    return shift->AddressLine2;
}


sub address_line {
    my $self = shift;
    my $line = $self->AddressLine1 || '';
    if (my $second = $self->AddressLine2) {
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
    return shift->Phone;
}

sub region {
    return shift->StateOrRegion;
}

1;
