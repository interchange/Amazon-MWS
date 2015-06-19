package Amazon::MWS::XML::Order;

use Amazon::MWS::XML::Address;
use Amazon::MWS::XML::OrderlineItem;

use strict;
use warnings;
use DateTime;
use DateTime::Format::ISO8601;
use Data::Dumper;

use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use namespace::clean;

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

Field description:

http://docs.developer.amazonservices.com/en_US/orders/2013-09-01/Orders_GetOrder.html

=head2 orderline

It should be the output of C<ListOrderItems> without the root, like
C<$response->{OrderItems}->{OrderItem}>.

=head2 retrieve_orderline_sub

If you want to save API calls, instead of initialize the orderline,
you may want to pass a subroutine (which will accept no arguments, so
it should be a closure) to the constructor instead, which will be
called lazily if the object needs to access the orderline.

=head2 order_number

Our order ID.

=head2 shipping_address

Shipping address as C<Amazon::MWS::Client::Address> object.

=cut


has order => (is => 'rw',
              required => 1,
              isa => HashRef);

has orderline => (is => 'lazy',
                  isa => ArrayRef);

has retrieve_orderline_sub => (is => 'ro',
                               isa => CodeRef);


sub _build_orderline {
    my $self = shift;
    my $sub = $self->retrieve_orderline_sub;
    die "Missing retrieve_orderline_sub" unless $sub;
    return $sub->();
}

has order_number => (is => 'rw');


=head1 METHODS

They are mostly shortcuts to retrieve the correct information.

=cut

sub amazon_order_number {
    return shift->order->{AmazonOrderId};
}

=head2 amazon_order_number

The Amazon order id.

=head2 remote_shop_order_id

Same as C<amazon_order_number>

=cut

sub remote_shop_order_id {
    return shift->amazon_order_number;
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

has first_name => (is => 'lazy');

sub _build_first_name {
    my $self = shift;
    my ($first, $last) = $self->_get_first_last_name;
    return $first || '';
}

has last_name => (is => 'lazy');

sub _build_last_name {
    my $self = shift;
    my ($first, $last) = $self->_get_first_last_name;
    return $last || '';
}

sub _get_first_last_name {
    my $self = shift;
    my $address = $self->shipping_address;
    die "Missing name in shipping address" unless $address->name;
    # this is totally euristic
    my ($first_name, $last_name) = split(/\s+/, $address->name, 2);
    return ($first_name, $last_name);
}


has items_ref => (is => 'lazy');

sub _build_items_ref {
    my ($self) = @_;
    my $orderline = $self->orderline;
    my @items;
    foreach my $item (@$orderline) {
        # print Dumper($item);
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

=head2 number_of_items

Total number of items ordered.

=cut

sub number_of_items {
    my $self = shift;
    my @items = $self->items;
    my $total = 0;
    foreach my $i (@items) {
        $total += $i->quantity;
    }
    return $total;
}


sub total_cost {
    my $self = shift;
    my $total_cost = sprintf('%.2f', $self->order->{OrderTotal}->{Amount});
    die "Couldn't retrieve the OrderTotal/Amount " . Dumper($self->order)
      unless defined $total_cost;
    my $subtotal = $self->subtotal;
    my $shipping = $self->shipping_cost;
    if (_kinda_equal($subtotal + $shipping, $total_cost)) {
        return $total_cost;
    }
    else {
        die "subtotal $subtotal + shipping $shipping is not $total_cost\n";
    }
}

sub currency {
    my $self = shift;
    my $currency = $self->order->{OrderTotal}->{CurrencyCode}; 
    die "Couldn't find OrderTotal/Currency " . Dumper($self->order)
      unless $currency;
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

sub _kinda_equal {
    return abs($_[0] - $_[1]) < 0.01;
}

=head2 reported_order_number

If the order was acknowlegded, we should find our order number in this
method (read-only, use the C<order_number> setter if you need to
ackwnoledge.

=cut

sub reported_order_number {
    return shift->order->{SellerOrderId};
}

=head2 order_is_shipped

Return true if the order is marked as shipped by Amazon

=cut

sub order_is_shipped {
    my $self = shift;
    my $status = $self->order_status;
    $status eq 'Shipped' ? return 1 : return;
}

=head2 order_status

Shortcut to orders' OrderStatus

=cut

sub order_status {
    return shift->order->{OrderStatus};
}

=head2 can_be_imported

Return false if the status is Pending or Canceled.

=cut

sub can_be_imported {
    my $self = shift;
    my $status = $self->order_status;
    if ($status eq 'Pending' or
        $status eq 'Canceled') {
        return;
    }
    else {
        return 1;
    }
}


=head2 shop_type

Returns C<amazon>

=head2 comments

Returns an empty string

=head2 payment_method

Returns C<Amazon>

=cut

sub shop_type {
    return 'amazon';
}

sub comments {
    # unclear if we have something like that
    return '';
}

sub payment_method {
    return 'Amazon';
}

sub shipping_method {
    # empty so far
    return '';
}


1;
