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

=head2 merchant_order_item

Our id

=cut

has merchant_order_item => (is => 'rw');

sub amazon_order_item {
    return shift->OrderItemId;
}

sub currency {
    return shift->ItemPrice->{CurrencyCode};
}

sub price {
    my $price = shift->ItemPrice->{Amount} || 0;
    return sprintf('%.2f', $price);
}

sub shipping {
    my $shipping =  shift->ShippingPrice->{Amount} || 0;
    return sprintf('%.2f', $shipping);
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
    return sprintf('%.2f', $self->price * $self->quantity);
}

sub as_ack_orderline_item_hashref {
    my $self = shift;
    return {
            AmazonOrderItemCode => $self->amazon_order_item,
            MerchantOrderItemID => $self->merchant_order_item,
           };
}


1;
