package Amazon::MWS::XML::Product;

use strict;
use warnings;

use Moo;

=head1 NAME

Amazon::MWS::XML::Product

=head1 DESCRIPTION

Class to handle the products and emit data structures suitable for XML
generation.

=head1 ACCESSORS

They has to be passed to the constructor

=over 4

=item sku

Mandatory.

=item ean

=item title

=item description

=item brand

=item inventory

Indicates whether or not an item is available (any positive number =
available; 0 = not available). Every time a quantity is sent for an
item, the existing quantity is replaced by the new quantity in the
feed

=item price

The price of the item.

=item ship_in_days

The number of days between the order date and the ship date (a whole
number between 1 and 30). If not specified the info will not be set
and Amazon will use a default of 2 business days, so we use the
default of 2 here.

=back

=cut

has sku => (is => 'ro', required => 1);
has ean => (is => 'ro');
has title => (is => 'ro');
has description => (is => 'ro');
has brand => (is => 'ro');

has inventory => (is => 'ro',
                  default => sub { '0' },
                  isa => sub {
                      die "Not an integer" unless $_[0] eq int($_[0]);
                  });


has price => (is => 'ro',
              isa => sub {
                  die "Not a price"
                    unless $_[0] =~ m/^[0-9]+(\.[0-9][0-9]?)?$/;
              });

has ship_in_days => (is => 'ro',
                     isa => sub {
                         die "Not an integer" unless $_[0] eq int($_[0]);
                     },
                     default => sub { '2' });


# has restock_date => (is => 'ro');


=head1 METHODS

=head2 as_product_hash

Return a data structure suitable to feed the Product slot in a Product
feed.

=head2 as_inventory_hash

Return a data structure suitable to feed the Inventory slot in a
Inventory feed.


=cut


sub as_product_hash {
    my $self = shift;
    my $data = {
        SKU => $self->sku,
    };
    if (my $ean = $self->ean) {
        $data->{StandardProductID} = {
            Type => 'EAN',
            Value => $ean,
           }
    }

    # this should be a no-brainer. Values are:
    # Club CollectibleAcceptable CollectibleGood
    #    CollectibleLikeNew CollectibleVeryGood New
    #    Refurbished UsedAcceptable UsedGood UsedLikeNew
    #    UsedVeryGood

    $data->{Condition} = { ConditionType => 'New' };

    # how many items in a package
    # $data->{ItemPackageQuantity} = 1
    # and totally
    # $data->{NumberOfItems} = 1

    if (my $title = $self->title) {
        $data->{DescriptionData}->{Title} = $title;
    }
    
    if (my $brand = $self->brand) {
        $data->{DescriptionData}->{Brand} = $brand;
    }
    if (my $desc = $self->description) {
        $data->{DescriptionData}->{Description} = $desc;
    }
     # $data->{ProductData} deals with categories.
    return $data;
}

sub as_inventory_hash {
    my $self = shift;
    return {
            SKU => $self->sku,
            Quantity => $self->inventory,
            FulfillmentLatency => $self->ship_in_days,
           };
}


1;
