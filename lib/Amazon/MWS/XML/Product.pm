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

=item timestamp_string

An arbitrary string (usually a timestamp) which identifies the
revision of the product.

=item ean

=item title

=item description

=item brand

=item category_code

=item category

To be used, both category and subcategory must be set.

=item subcategory

To be used, both category and subcategory must be set.

=item inventory

Indicates whether or not an item is available (any positive number =
available; 0 = not available). Every time a quantity is sent for an
item, the existing quantity is replaced by the new quantity in the
feed.

This accessor is read-write because L<Amazon::MWS::Uploader> may want
to throttle the inventory. Other code is discouraged to use this as a
modifier.

=item ship_in_days

The number of days between the order date and the ship date (a whole
number between 1 and 30). If not specified the info will not be set
and Amazon will use a default of 2 business days, so we use the
default of 2 here.

=item price

The standard price of the item.

=item currency

Default to EUR. Valid values are: AUD BRL CAD CNY DEFAULT EUR GBP INR
JPY MXN USD.

Default to EUR.

=item sale_price

A sale price (optional)

=item sale_start

A DateTime object with the sale start date

=item sale_end

A DateTime object with the sale end date

=item images

An (optional) arrayref of image urls. The first will become the main
image, the other one will become the PT1, etc.

=item children

An (optional) arraryref of children sku.

=item search_terms

An (optional) arrayref of search terms (max 5)

=item features

An (optional) arrayref of strings with features (max 5)

=item condition

Possible values which validates correctly: Club CollectibleAcceptable
CollectibleGood CollectibleLikeNew CollectibleVeryGood New Refurbished
UsedAcceptable UsedGood UsedLikeNew UsedVeryGood

Defaults to C<New>

=item condition_note

An arbitrary string shorter than 2000 characters with comments about
the condition.

=back

=cut

has sku => (is => 'ro', required => 1);
has timestamp_string => (is => 'ro',
                         default => sub { '0' });
has ean => (is => 'ro');
has title => (is => 'ro');
has description => (is => 'ro');
has brand => (is => 'ro');
has condition => (is => 'ro',
                  default => sub { 'New' },
                  isa => sub {
                      my %condition_map = (
                                           Club                   => 1,
                                           CollectibleAcceptable  => 1,
                                           CollectibleGood        => 1,
                                           CollectibleLikeNew     => 1,
                                           CollectibleVeryGood    => 1,
                                           New                    => 1,
                                           Refurbished            => 1,
                                           UsedAcceptable         => 1,
                                           UsedGood               => 1,
                                           UsedLikeNew            => 1,
                                           UsedVeryGood           => 1,
                                          );
                      my $cond = $_[0];
                      die "Unrecognized condition $cond, must be one of the following: "
                        . join(' ', keys %condition_map) unless $condition_map{$cond};
                  });
has condition_note => (
                       is => 'ro',
                       isa => sub {
                           die "Max lenght is 2000"
                             if length($_[0]) > 2000 },
                      );
has category_code => (is => 'ro');
has manufacturer_part_number => (is => 'ro');
has search_terms => (is => 'ro', isa => sub { die unless ref($_[0]) eq 'ARRAY' });
has features => (is => 'ro', isa => sub { die unless ref($_[0]) eq 'ARRAY' });
has category => (is => 'ro');
has subcategory => (is => 'ro');

sub _check_units {
    my $unit = $_[0];
    my %units = (
                 GR => 1,
                 KG => 1,
                 LB => 1,
                 MG => 1,
                 OZ => 1,
                );
    die "Wrong unit. Possible are :"
      . join(" ", keys %units) unless $units{$unit};
}

=over 4

=item package_weight

Weight of the package.

=item package_weight_unit

Unit for the package weight. Possible values are C<GR>, C<KG>, C<LB>,
C<MG>, C<OZ>. Defaults to C<GR>.

=item shipping_weight

Weight of the product when packaged to ship.

=item shipping_weight_unit

Unit for the package weight for shipping. Possible values are C<GR>,
C<KG>, C<LB>, C<MG>, C<OZ>. Defaults to C<GR>.

=back

=cut

has package_weight => (is => 'ro');

has package_weight_unit => (is => 'ro',
                            default => sub { 'GR' },
                            isa => \&_check_units,
                           );

has shipping_weight => (is => 'ro');

has shipping_weight_unit => (is => 'ro',
                             default => sub { 'GR' },
                             isa => \&_check_units,
                            );

has inventory => (is => 'rw',
                  default => sub { '0' },
                  isa => sub {
                      die "Not an integer" unless $_[0] eq int($_[0]);
                  });

has ship_in_days => (is => 'ro',
                     isa => sub {
                         die "Not an integer" unless $_[0] eq int($_[0]);
                     },
                     default => sub { '2' });

has price => (is => 'ro',
              isa => sub {
                  die "Not a price"
                    unless $_[0] =~ m/^[0-9]+(\.[0-9][0-9]?)?$/;
              });

has sale_price => (is => 'ro',
                   isa => sub {
                       die "Not a price: $_[0]"
                         unless $_[0] =~ m/^[0-9]+(\.[0-9][0-9]?)?$/;
                   });

has sale_start => (is => 'ro',
                   isa => sub {
                       die "Not a datetime"
                         unless $_[0]->isa('DateTime');
                   });

has sale_end => (is => 'ro',
                   isa => sub {
                       die "Not a datetime"
                         unless $_[0]->isa('DateTime');
                   });

has currency => (is => 'ro',
                 isa => sub {
                     my %currency = map { $_ => 1 } (qw/AUD BRL CAD CNY DEFAULT
                                                        EUR GBP INR JPY MXN USD/);
                     die "Not a valid currency" unless $currency{$_[0]};
                 },
                 default => sub { 'EUR' });

has images => (is => 'ro',
               isa => sub {
                   die "Not an arrayref" unless ref($_[0]) eq 'ARRAY';
               });

has children => (is => 'ro',
                 isa => sub {
                     die "Not an arrayref" unless ref($_[0]) eq 'ARRAY';
                 });


# has restock_date => (is => 'ro');


=head1 METHODS

=head2 as_product_hash

Return a data structure suitable to feed the Product slot in a Product
feed.

=head2 as_inventory_hash

Return a data structure suitable to feed the Inventory slot in a
Inventory feed. Negative quantities will be normalized to 0.

=head2 as_price_hash

Return a data structure suitable to feed the Price slot in a
Price feed.

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

    $data->{Condition} = { ConditionType => $self->condition };
    if (my $cond_note = $self->condition_note) {
        $data->{Condition}->{ConditionNote} = $cond_note;
    }

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
    if (my $cat = $self->category_code) {
        $data->{DescriptionData}->{RecommendedBrowseNode} = $cat;
    }
    if (my $manufacturer_part = $self->manufacturer_part_number) {
        $data->{DescriptionData}->{MfrPartNumber} = $manufacturer_part;
    }
    if (my $search_terms = $self->search_terms) {
        if (my @terms = @$search_terms) {
            if (@terms > 5) {
                warn "Max terms is 5, removing some of them: " .
                  join(" ", splice(@terms, 5)) . "\n";
            }
            my @filtered = map { substr $_, 0, 50 } @terms;
            $data->{DescriptionData}->{SearchTerms} = \@filtered;
        }
    }
    if (my $features = $self->features) {
        if (my @feats = grep { $_ } @$features) {
            if (@feats > 5) {
                warn "Max features is 5, removing some of them: " .
                  join(" ", splice(@feats, 5)) . "\n";
            }
            splice(@feats, 5);
            $data->{DescriptionData}->{BulletPoint} = \@feats;
        }
    }

    if (my $weight = $self->package_weight) {
        my $unit = $self->package_weight_unit;
        $data->{DescriptionData}->{PackageWeight} = {
                                                     unitOfMeasure => $unit,
                                                     _ => $weight,
                                                    };
    }
    if (my $ship_weight = $self->shipping_weight) {
        my $unit = $self->shipping_weight_unit;
        $data->{DescriptionData}->{ShippingWeight} = {
                                                     unitOfMeasure => $unit,
                                                     _ => $ship_weight,
                                                    };
    }

    if ($self->category && $self->subcategory) {
        # suspicious structure
        $data->{ProductData}->{$self->category}->{ProductType}->{$self->subcategory} = {};
    }
    return $data;
}

sub as_inventory_hash {
    my $self = shift;
    my $quantity = $self->inventory;
    if ($quantity < 0) {
        $quantity = 0;
    }
    return {
            SKU => $self->sku,
            Quantity => $quantity,
            FulfillmentLatency => $self->ship_in_days,
           };
}

sub as_price_hash {
    my $self = shift;
    my $price = $self->price;
    die $self->sku . " has price lesser than 0: $price\n" if $price < 0;
    my $data = {
                SKU => $self->sku,
                StandardPrice => { currency => $self->currency,
                                   _ => sprintf('%.2f', $self->price) },
               };
    if ($self->sale_price) {
        if ($self->sale_start && $self->sale_end) {
            $data->{Sale} = {
                             SalePrice => { currency => $self->currency,
                                            _ => sprintf('%.2f', $self->sale_price) },
                             StartDate => $self->sale_start->iso8601,
                             EndDate   => $self->sale_end->iso8601,
                            };
        }
        else {
            warn "Ignoring sale price, missing start or end date for "
              . $self->sku . "\n";
        }
    }
    return $data;
}

=head2 as_image_hash

Return a data structure suitable to feed the ProductImage slot in a
Image feed.

=over 4

=item SKU

=item ImageType The type of image (Main, Alternate, or Swatch)

=over 4

=item Main - Main image for the product

=item Alternate (PT) - Other views of the product

=item Swatch - Color or fabric (Note: Swatch images will be scaled down to 30 x 30 pixels
so they should only be used for displaying the color of your product's fabric, for
example, not for displaying your whole product.)

=back

=item ImageLocation

The exact location of the image using a full URL (such as
http://mystore.com/images/1234.jpg). Amazon cannot access images
stored with a secured URL (https) so be sure to use http instead.

=back

=cut

sub as_images_array {
    my $self = shift;
    # for now just push the main image
    return unless $self->images;
    my $sku = $self->sku;
    # here we assign the first as the main one, the others as alternate.
    my @images = @{ $self->images };
    my @types = (qw/Main PT1 PT2 PT3 PT4 PT5 PT6 PT7 PT8/);

    my @out;

    while (@images && @types) {
        my $img = shift @images;
        my $type = shift @types;
        push @out, {
                    SKU => $sku,
                    ImageType => $type,
                    ImageLocation => $img,
                   };
    }
    @out ? return \@out : return;
}

=head2 as_variants_hash

Return a structure suitable for the Relationship feed.

=cut

sub as_variants_hash {
    my $self = shift;
    my $children = $self->children;
    return unless $children;
    my $data = { ParentSKU => $self->sku,
                 Relation => [] };
    foreach my $child (@$children) {
        push @{ $data->{Relation} }, {
                                      SKU => $child,
                                      Type => 'Variation',
                                     };
    }
    return $data;
}

=head2 condition_type_for_lowest_price_listing

This is a method, not an accessor. Extract from the condition the
string needed by some API calls, where possible values are: New Used
Collectible Refurbished Club

=cut



sub condition_type_for_lowest_price_listing {
    my $self = shift;
    my $condition = $self->condition;
    die "Shouldn't happen" unless $condition;
    # beware the hack
    if ($condition =~ m/^([A-Z][a-z]+)$/) {
        return $condition;
    }
    elsif ($condition =~ m/^([A-Z][a-z]+)([A-Z][a-z]+)$/) {
        return $1;
    }
    else {
        die "$condition?";
    }
}


1;
