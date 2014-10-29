package Amazon::MWS::XML::Order;

use Amazon::MWS::XML::Address;
use Amazon::MWS::XML::OrderlineItem;

use strict;
use warnings;
use DateTime;
use DateTime::Format::ISO8601;

use Moo;

=head1 NAME

Amazon::MWS::XML::Order

=head1 DESCRIPTION

Class to handle the xml structures returned by ListOrders and
ListOrderItems.

The constructor is meant to be called by L<Amazon::MWS::Uploader> when
C<get_orders> is called. A list of objects of this class will be
returned.

=head1 SYNOPSIS

 my $order = Amazon::MWS::XML::Order->new(order => $struct, orderline => \@struct);
 my @items = $order->items;
 print $order->order_number, $order->amazon_order_number;

=head1 ACCESSORS

They should be passed to the constructor and are complex structures
parsed from the output of L<Amazon::MWS::Client>.

=head2 order

It should be the output of C<ListOrders> or C<GetOrder> without the
root, e.g. C<$response->{Orders}->{Order}->[0]>

=head2 orderline

It should be the output of C<ListOrderItems> without the root, like
C<$response->{OrderItems}->{OrderItem}>.

=head2 order_number

Our order ID.

=cut


has order => (is => 'rw',
              required => 1,
              isa => sub {
                  die unless ref($_[0]) eq 'HASH';
              });

has orderline => (is => 'rw',
                  required => 1,
                  isa => sub {
                      die unless ref($_[0]) eq 'ARRAY';
                  });

has order_number => (is => 'rw');


=head1 METHODS

They are mostly shortcuts to retrieve the correct information.

=cut

sub amazon_order_number {
    return shift->order->{AmazonOrderId};
}

sub email {
    return shift->order->{BuyerEmail};
}

has shipping_address => (is => 'lazy');
                         
sub _build_shipping_address {
    my $self = shift;
    my $address = $self->order->{ShippingAddress};
    return Amazon::MWS::XML::Address->new(%$address);
}

has items_ref => (is => 'lazy');

sub _build_items_ref {
    my ($self) = @_;
    my $orderline = $self->orderline;
    my @items;
    foreach my $item (@$orderline) {
        push @items, Amazon::MWS::XML::OrderlineItem->new(%$item);
    }
    return \@items;
}

sub items {
    my $self = shift;
    return @{ $self->items_ref };
}

=head2 order_date

Return a L<DateTime> object with th purchase date.

=cut

sub order_date {
    my ($self) = @_;
    return $self->_get_dt($self->order->{PurchaseDate});
}

sub _get_dt {
    my ($self, $date) = @_;
    return DateTime::Format::ISO8601->parse_datetime($date);
}

sub shipping_cost {
    my $self = shift;
    my @items = $self->items;
    my $shipping = 0;
    foreach my $i (@items) {
        $shipping += $i->shipping;
    }
    return sprintf('%.2f', $shipping);
}

sub subtotal {
    my $self = shift;
    my @items = $self->items;
    my $total = 0;
    foreach my $i (@items) {
        $total += $i->subtotal;
    }
    return sprintf('%.2f', $total);
}

sub total_cost {
    my $self = shift;
    my $total_cost = $self->order->{OrderTotal}->{Amount};
    die "Couldn't retrieve the OrderTotal/Amount" unless defined $total_cost;
    unless (($self->subtotal + $self->shipping_cost) == $total_cost) {
        die $self->subtotal . " + " . $self->shipping_cost . " is not $total_cost";
    }
    return sprintf('%.2f', $total_cost);
}

sub currency {
    my $self = shift;
    my $currency = $self->order->{OrderTotal}->{CurrencyCode}; 
    die "Couldn't find OrderTotal/Currency" unless $currency;
    return $currency;
}

sub as_ack_order_hashref {
    my $self = shift;
    my @items;
    foreach my $item ($self->items) {
        push @items, $item->as_ack_orderline_item_hashref;
    }
    return {
            AmazonOrderID => $self->amazon_order_number,
            MerchantOrderID => $self->order_number,
            Item => \@items,
           };
}

1;
