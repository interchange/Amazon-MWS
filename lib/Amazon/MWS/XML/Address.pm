package Amazon::MWS::XML::Address;

use strict;
use warnings;

use Moo;

=head2 ACCESSORS

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
