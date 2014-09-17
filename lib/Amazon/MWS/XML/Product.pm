# -*- cperl-indent-parens-as-block: 1 -*-
package Amazon::MWS::XML::Product;

use strict;
use warnings;

use Moo;

=head1 NAME

Amazon::MWS::XML::Product

=head1 DESCRIPTION

Class to handle the products and emit data structures suitable for XML
generation.

=cut

has sku => (is => 'ro', required => 1);
has ean => (is => 'ro');
has title => (is => 'ro');
has description => (is => 'ro');
has brand => (is => 'ro');

sub as_hash {
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

1;
