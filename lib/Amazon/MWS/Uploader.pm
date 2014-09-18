package Amazon::MWS::Uploader;

use strict;
use warnings;

use DBI;
use Amazon::MWS::XML::Feed;
use Amazon::MWS::Client;
use XML::LibXML::Simple qw/XMLin/;
use Data::Dumper;

use Moo;
use namespace::clean;


=head1 NAME

Amazon::MWS::Uploader -- high level agent to upload products to AMWS

=head1 DESCRIPTION

This module provide an high level interface to the upload process. It
has to keep track of the state to resume the uploading, which could
get stuck on the Amazon's side processing, so database credentials
have to be provided (or the database handle itself).

The table structure needed is defined and commented in sql/amazon.sql

=head1 SYNOPSIS

  my $agent = Amazon::MWS::Uploader->new(
                                         db_dsn => 'DBI:mysql:database=XXX',
                                         db_username => 'xxx',
                                         db_password => 'xxx',
                                         db_options => \%options
                                         # or dbh => $dbh,
  
                                         schema_dir => '/path/to/xml_schema',
                                         feed_dir => '/path/to/directory/for/xml',
  
                                         merchant_id => 'xxx',
                                         access_key_id => 'xxx',
                                         secret_key => 'xxx',
  
                                         marketplace_id => 'xxx',
                                         endpoint => 'xxx',
  
                                         products => \@products,
                                        );
  
  # say once a day, retrieve the full batch and send it up
  $agent->upload; 
  
  # every 10 minutes or so, continue the work started with ->upload, if any
  $agent->resume;


=head1 ACCESSORS

The following keys must be passed at the constructor and can be
accessed read-only:

=over 4

=item dbh

The DBI handle. If not provided will be built using the following
self-describing accessor:

=item db_dns

=item db_username

=item db_password

=item db_options

E.g.

  {
   mysql_enable_utf8 => 1,
  }

AutoCommit and RaiseError are set by us.

=cut

has db_dsn => (is => 'ro');
has db_password => (is => 'ro');
has db_username => (is => 'ro');
has db_options => (is => 'ro',
                   isa => sub {
                       die "Not an hashref" unless ref($_[0]) eq 'HASH';
                   });
has dbh => (is => 'lazy');

sub _build_dbh {
    my $self = shift;
    my $dsn = $self->db_dsn;
    die "Missing dns" unless $dsn;
    my $options = $self->db_options || {};
    # forse raise error and auto-commit
    $options->{RaiseError} = 1;
    $options->{AutoCommit} = 1;
    my $dbh = DBI->connect($dsn, $self->db_username, $self->db_password,
                           $options) or die "Couldn't connect to $dsn!";
    return $dbh;
}

=item schema_dir

The directory where the xsd files for the feed building can be found.

=item feeder

A L<Amazon::MWS::XML::Feed> object. Lazy attribute, you shouldn't pass
this to the constructor, it is lazily built using C<products>,
C<merchant_id> and C<schema_dir>.

=item feed_dir

A working directory where to stash the uploaded feeds for inspection
if problems are detected.

=cut

has schema_dir => (is => 'ro',
                   required => 1,
                   isa => sub {
                       die "$_[0] is not a directory" unless -d $_[0];
                   });

has feed_dir => (is => 'ro',
                 required => 1,
                 isa => sub {
                     die "$_[0] is not a directory" unless -d $_[0];
                 });

has feeder => (is => 'lazy');

sub _build_feeder {
    my $self = shift;
    my $products = $self->products;
    die "Missing products, can't build a feeder!" unless $products && @$products;
    my $feeder = Amazon::MWS::XML::Feed->new(
                                             products => $products,
                                             schema_dir => $self->schema_dir,
                                             merchant_id => $self->merchant_id,
                                            );
    return $feeder;
}


=item merchant_id

The merchant ID provided by Amazon.

=item access_key_id

Provided by Amazon.

=item secret_key

Provided by Amazon.

=item marketplace_id

http://docs.developer.amazonservices.com/en_US/dev_guide/DG_Endpoints.html

=item endpoint

Ditto.

=cut

has merchant_id => (is => 'ro', required => 1);
has access_key_id => (is => 'ro', required => 1);
has secret_key => (is => 'ro', required => 1);
has marketplace_id => (is => 'ro', required => 1);
has endpoint => (is => 'ro', required => 1);

=item products

An arrayref of L<Amazon::MWS::XML::Product> objects, or anything that
(properly) responds to C<as_product_hash>, C<as_inventory_hash>,
C<as_price_hash>. See L<Amazon::MWS::XML::Product> for details.

B<This is set as read-write, so you can set the product after the
object construction, but if you change it afterward, you will get
unexpected results>.

=back

=cut

has products => (is => 'rw',
                 isa => sub {
                     die "Not an arrayref" unless ref($_[0]) eq 'ARRAY';
                 });

=item client

An L<Amazon::MWS::Client> object, built lazily, so you don't have to
pass it.

=cut

has client => (is => 'lazy');

sub _build_client {
    my $self = shift;
    my %mws_args = map { $_ => $self->$_ } (qw/merchant_id
                                               marketplace_id
                                               access_key_id
                                               secret_key
                                               endpoint/);

    return Amazon::MWS::Client->new(%mws_args);
}


=head1 METHODS

=cut




1;
