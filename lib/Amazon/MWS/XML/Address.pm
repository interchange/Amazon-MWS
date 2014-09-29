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

1;
