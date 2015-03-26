package Amazon::MWS::XML::Response::OrderReport::Item;

use utf8;
use strict;
use warnings;
use MooX::Types::MooseLike::Base qw(Int Str HashRef);
use namespace::clean;
use Moo;

=head1 NAME

Amazon::MWS::XML::Response::OrderReport::Item

=head1 DESCRIPTION

Class which handles the xml structures reported by the C<GetReport>
with type C<OrderReport> in the C<Item> slot (the orderline's items).

The class should act like L<Amazon::MWS::XML::OrderlineItem> when
applicable.

=head1 ACCESSORS

They correspond to the documented structure. They should not be called
directly, though, prefer the methods above.

=over 4
=item Title              
=item Quantity           
=item SKU                
=item ItemPrice          
=item ProductTaxCode     
=item AmazonOrderItemCode
=item ItemFees           
=back

=cut

has Title               => (is => 'ro', isa => Str);
has Quantity            => (is => 'ro', isa => Int);
has SKU                 => (is => 'ro', isa => Str);
has ItemPrice           => (is => 'ro', isa => HashRef);
has ProductTaxCode      => (is => 'ro', isa => Str);
has AmazonOrderItemCode => (is => 'ro', isa => Str);
has ItemFees            => (is => 'ro', isa => HashRef);

=head2 merchant_order_item

Our id (read-write).

=head1 METHODS AND SHORTCUTS

All the methods are read only.

=over 4

=item shipping

=item subtotal

If there are taxes in the amazon price component, they are excluded.

=item price

Individual price of a single item.

=item tax

=item shipping_tax

=item currency

=item name

=item sku

=item amazon_order_item

=item as_ack_orderline_item_hashref

=back

=cut

has merchant_order_item => (is => 'rw',
                            default => sub { '' });

has shipping => (is => 'lazy');
has subtotal => (is => 'lazy');
has tax => (is => 'lazy');
has shipping_tax => (is => 'lazy');
has price => (is => 'lazy');

sub _build_shipping {
    return shift->_get_price_component('Shipping');
}

sub _build_subtotal {
    return shift->_get_price_component('Principal');
}

sub _build_tax {
    return shift->_get_price_component('Tax');
}

sub _build_shipping_tax {
    return shift->_get_price_component('ShippingTax');
}

sub _build_price {
    my $self = shift;
    return sprintf('%.2f', $self->subtotal / $self->quantity);
}

has currency => (is => 'lazy');

sub _build_currency {
    my $self = shift;
    my $currency;
    if (my $components = $self->ItemPrice->{Component}) {
        foreach my $comp (@$components) {
            last if $currency = $comp->{Amount}->{currency};
        }
    }
    return $currency;
}

sub _get_price_component {
    my ($self, $type) = @_;
    die unless $type;
    my $amount = 0;
    if (my $components = $self->ItemPrice->{Component}) {
        foreach my $comp (@$components) {
            if ($type eq $comp->{Type}) {
                $amount += $comp->{Amount}->{_};
            }
        }
    }
    return sprintf('%.2f', $amount);
}


sub sku {
    return shift->SKU;
}

sub quantity {
    return shift->Quantity;
}

sub name {
    return shift->Title;
}

sub amazon_order_item {
    return shift->AmazonOrderItemCode;
}

sub as_ack_orderline_item_hashref {
    my $self = shift;
    return {
            AmazonOrderItemCode => $self->amazon_order_item,
            MerchantOrderItemID => $self->merchant_order_item,
           };

}


1;
