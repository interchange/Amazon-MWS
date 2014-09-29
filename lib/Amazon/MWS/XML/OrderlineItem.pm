package Amazon::MWS::XML::OrderlineItem;

use strict;
use warnings;
use Moo;


=head ACCESSOR

=cut

has PromotionDiscount => (is => 'ro',
                          isa => sub { die unless ref($_[0]) eq 'HASH'});

has Title => (is => 'ro');

has OrderItemId => (is => 'ro');

has ASIN => (is => 'ro');

has GiftWrapPrice => (is => 'ro',
                      isa => sub { die unless ref($_[0]) eq 'HASH'});

has GiftWrapTax => (is => 'ro',
                    isa => sub { die unless ref($_[0]) eq 'HASH'});

has SellerSKU => (is => 'ro');

has ShippingPrice => (is => 'ro',
                      isa => sub { die unless ref($_[0]) eq 'HASH'});

has ShippingTax => (is => 'ro',
                    isa => sub { die unless ref($_[0]) eq 'HASH'});

has ShippingDiscount => (is => 'ro',
                         isa => sub { die unless ref($_[0]) eq 'HASH'});

has ItemTax => (is => 'ro',
                isa => sub { die unless ref($_[0]) eq 'HASH'});

has ConditionId => (is => 'ro');

has ItemPrice => (is => 'ro',
                  isa => sub { die unless ref($_[0]) eq 'HASH'});

has ConditionSubtypeId => (is => 'ro');

has QuantityShipped => (is => 'ro');
has QuantityOrdered => (is => 'ro');

sub currency {
    return shift->ItemPrice->{CurrencyCode};
}

sub price {
    return shift->ItemPrice->{Amount} || 0;
}

sub shipping {
    return shift->ShippingPrice->{Amount} || 0;
}

sub sku {
    return shift->SellerSKU;
}
sub asin {
    return shift->ASIN;
}

sub quantity {
    return shift->QuantityOrdered;
}

sub name {
    return shift->Title;
}

sub subtotal {
    my $self = shift;
    # and possibly others...
    return $self->price + $self->shipping;
}

1;
