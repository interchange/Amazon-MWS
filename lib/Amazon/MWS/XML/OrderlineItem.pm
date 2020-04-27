package Amazon::MWS::XML::OrderlineItem;

use strict;
use warnings;
use Moo;


=head1 ACCESSORS (they map the XML data)

=over 4

=item PromotionDiscount

=item Title

=item OrderItemId

=item ASIN

=item GiftWrapPrice

=item GiftWrapTax

=item SellerSKU

=item ShippingPrice

=item ShippingTax

=item ShippingDiscount

=item ItemTax

=item ConditionId

=item ItemPrice

=item ConditionSubtypeId

=item QuantityShipped

=item QuantityOrdered

=back

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

=head2 amazon_order_item

The amazon id for the given item (read-only)

=head2 remote_shop_order_item

Alias for C<amazon_order_item>

=head2 merchant_order_item

Our id (read-write).

=head2 currency

The currency code.

=cut

has merchant_order_item => (is => 'rw');

sub amazon_order_item {
    return shift->OrderItemId;
}

sub remote_shop_order_item {
    return shift->amazon_order_item;
}


sub currency {
    return shift->ItemPrice->{CurrencyCode};
}

=head2 include_tax_in_prices

Boolean flag to indicate if the computed subtotal, price and shipping
should include the tax or not. At the time of writing, the behavior
depends on varius factors (business account, Amazon instance). Default
to false.

=cut

has include_tax_in_prices => (is => 'ro', default => sub { 0 });

=head2 price

Amazon report the item price's as the sum of the items, not the
individual price. So we have to do a division for what we know as the
item's price. This looks ugly anyway.

From
L<https://docs.developer.amazonservices.com/en_US/orders-2013-09-01/Orders_ListOrderItems.html>:

The selling price of the order item. Note that an order item is an
item and a quantity. This means that the value of ItemPrice is equal
to the selling price of the item multiplied by the quantity ordered.
Note that ItemPrice excludes ShippingPrice and GiftWrapPrice.

It B<includes taxes> if C<include_tax_in_prices> is true.

=cut

sub price {
    my $self = shift;
    return sprintf('%.2f', $self->subtotal / $self->quantity);
}

=head2 shipping

The ShippingPrice amount.

It B<includes taxes> if C<include_tax_in_prices> is true.

=head2 subtotal

The price of the items for the given quantity (see above, C<price>).

It B<includes taxes> if C<include_tax_in_prices> is true.

=cut

sub shipping {
    my $self = shift;
    my $shipping = 0;
    if (my $price = $self->ShippingPrice) {
        $shipping = $price->{Amount} || 0;
    }
    if ($self->include_tax_in_prices) {
        $shipping += $self->shipping_tax;
    }
    return sprintf('%.2f', $shipping);
}

=head2 as_ack_orderline_item_hashref

Return an hashref suitable for the building of an ack order feed.

=cut

=head2 Aliases

=over 4

=item sku (SellerSKU)

=item asin (ASIN)

=item quantity (QuantityOrdered)

=item name (Title)

=back


=cut

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
    my $amount = 0;
    if (my $price = $self->ItemPrice) {
        $amount = $price->{Amount} || 0;
    }
    if ($self->include_tax_in_prices) {
        $amount += $self->item_tax;
    }
    return sprintf('%.2f', $amount);
}

sub as_ack_orderline_item_hashref {
    my $self = shift;
    return {
            AmazonOrderItemCode => $self->amazon_order_item,
            MerchantOrderItemID => $self->merchant_order_item,
           };
}

=head2 item_tax

The item tax amount reported by Amazon. If this is included or not in the
price varies, see L</include_tax_in_prices>

=cut

sub item_tax {
    my $self = shift;
    if (my $tax = $self->ItemTax) {
        return $tax->{Amount} || 0;
    }
    return 0;
}

=head2 shipping_tax

The Tax amounts reported by Amazon. If this is included or not in the
price varies, see L</include_tax_in_prices>.

=cut

sub shipping_tax {
    my $self = shift;
    if (my $tax = $self->ShippingTax) {
        return $tax->{Amount} || 0;
    }
    return 0;
}


1;
