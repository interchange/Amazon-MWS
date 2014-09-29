package Amazon::MWS::XML::Order;

use Amazon::MWS::XML::Address;
use Amazon::MWS::XML::OrderlineItem;

use strict;
use warnings;

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

=head1 METHODS

They are mostly shortcuts to retrieve the correct information.

=cut

sub order_number {
    # for now return undef. Probably when acknowledged, we will get
    # ours somewhere
    return;
}

sub amazon_order_number {
    return shift->order->{AmazonOrderId};
}

sub email {
    return shift->order->{BuyerEmail};
}

sub shipping_address {
    my $address = shift->order->{ShippingAddress};
    return Amazon::MWS::XML::Address->new(%$address);
}

sub items {
    my ($self) = @_;
    my $orderline = $self->orderline;
    my @items;
    foreach my $item (@$orderline) {
        push @items, Amazon::MWS::XML::OrderlineItem->new(%$item);
    }
    return @items;
}

1;
