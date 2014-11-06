package Amazon::MWS::Uploader;

use strict;
use warnings;

use DBI;
use Amazon::MWS::XML::Feed;
use Amazon::MWS::XML::Order;
use Amazon::MWS::Client;
use Amazon::MWS::XML::Response::FeedSubmissionResult;
use Data::Dumper;
use File::Spec;
use DateTime;
use SQL::Abstract;
use Try::Tiny;

use Moo;
use namespace::clean;

our $VERSION = '0.01';


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

has debug => (is => 'ro');

has logfile => (is => 'ro');

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

sub generic_feeder {
    my $self = shift;
    return Amazon::MWS::XML::GenericFeed->new(
                                              schema_dir => $self->schema_dir,
                                              merchant_id => $self->merchant_id,
                                             );
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

=item sqla

Lazy attribute to hold the C<SQL::Abstract> object.

=back

=cut

has products => (is => 'rw',
                 isa => sub {
                     die "Not an arrayref" unless ref($_[0]) eq 'ARRAY';
                 });

has sqla => (
             is => 'ro',
             default => sub {
                 return SQL::Abstract->new;
             }
            );

has existing_products => (is => 'lazy');

sub _build_existing_products {
    my $self = shift;
    my $sth = $self->_exe_query($self->sqla->select(amazon_mws_products => [qw/sku
                                                                               timestamp_string
                                                                               status
                                                                              /])),
    my %uploaded;
    while (my $row = $sth->fetchrow_hashref) {
        $row->{timestamp_string} ||= 0;
        $uploaded{$row->{sku}} = $row;
    }
    return \%uploaded;
}

has products_to_upload => (is => 'lazy');

sub _build_products_to_upload {
    my $self = shift;
    my $product_arrayref = $self->products;
    return unless $product_arrayref && @$product_arrayref;
    my @products = @$product_arrayref;
    my $existing = $self->existing_products;
    my @todo;
    foreach my $product (@products) {
        if (my $exists = $existing->{$product->sku}) {
            # skip already uploaded products with the same timestamp string.
            if ($exists->{status} and $exists->{status} eq 'ok') {
                if ($exists->{timestamp_string} eq ($product->timestamp_string || 0)) {
                    print "Skipping already uploaded item " . $product->sku . "\n";
                    next;
                }
            }
            # skip products in progress or failed.
            if ($exists->{status}) {
                # something else is going on. Pending or failed
                print "Skipping $exists->{status} item " . $product->sku . "\n";
                next;
            }
        }
        push @todo, $product;
    }
    # delete those skus from the db, we will insert them again aftward
    $self->_exe_query($self->sqla->delete('amazon_mws_products',
                                          { sku => { -in => [map { $_->sku } @todo] } }));
    return \@todo;
}


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
                                               debug
                                               logfile
                                               endpoint/);

    return Amazon::MWS::Client->new(%mws_args);
}


=head1 MAIN METHODS

=head2 upload

If the products is set, begin the routine to upload them. Because of
the asynchronous way AMWS works, at some point it will bail out,
saving the state in the database. You should reinstantiate the object
and call C<resume> on it every 10 minutes or so.

The workflow is described here:
L<http://docs.developer.amazonservices.com/en_US/feeds/Feeds_Overview.html>

This has to be done for each feed: Product, Inventory, Price, Image,
Relationship (for variants).

This method first generate the feeds in the feed directory, and then
calls C<resume>, which is in charge for the actual uploading.

=head2 resume

Restore the state and resume where it was left.

=head1 INTERNAL METHODS

=head2 prepare_feeds($type, { name => $feed_name, content => "<xml>..."}, { name => $feed_name2, content => "<xml>..."}, ....)

Prepare the feed of type $type with the feeds provided as additional
arguments.

Return the job id


=cut

sub _feed_file_for_method {
    my ($self, $job_id, $feed_type) = @_;
    die unless $job_id && $feed_type;
    my $feed_subdir = File::Spec->catdir($self->feed_dir,
                                         $job_id);
    unless ( -d $feed_subdir) {
        mkdir $feed_subdir;
    }
    my $file = File::Spec->catfile($feed_subdir, $feed_type . '.xml');
    return File::Spec->rel2abs($file)
}

sub _slurp_file {
    my ($self, $file) = @_;
    open (my $fh, '<', $file) or die "Couldn't open $file $!";
    local $/ = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub upload {
    my $self = shift;
    # create the feeds to be uploaded using the products
    my @products = @{ $self->products_to_upload };
    unless (@products) {
        print "No products, can't upload anything\n";
        return;
    }
    my $feeder = Amazon::MWS::XML::Feed->new(
                                             products => \@products,
                                             schema_dir => $self->schema_dir,
                                             merchant_id => $self->merchant_id,
                                            );
    my @feeds;
    foreach my $feed_name (qw/product
                              inventory
                              price
                              image
                              variants
                             /) {
        my $method = $feed_name . "_feed";
        my $content = $feeder->$method;
        push @feeds, {
                      name => $feed_name,
                      content => $content,
                     }
    }
    my $job_id = $self->prepare_feeds(upload => \@feeds);
    $self->_mark_products_as_pending($job_id, @products);
}

sub _mark_products_as_pending {
    my ($self, $job_id, @products) = @_;
    die "Bad usage" unless $job_id;
    # these skus were cleared up when asking for the products to upload
    foreach my $p (@products) {
        $self->_exe_query($self->sqla->insert(amazon_mws_products => {
                                                                      amws_job_id => $job_id,
                                                                      sku => $p->sku,
                                                                      status => 'pending',
                                                                      timestamp_string => $p->timestamp_string,
                                                                     }));
    }
}


sub prepare_feeds {
    my ($self, $task, $feeds) = @_;
    die "Missing task ($task) and feeds ($feeds)" unless $task && $feeds;
    my $job_id = $task . "-" . DateTime->now->strftime('%F-%H-%M');

    $self->_exe_query($self->sqla
                      ->insert(amazon_mws_jobs => {
                                                   amws_job_id => $job_id,
                                                   task => $task,
                                                  }));

    # to complete the process, we need to fill out these five
    # feeds. every feed has the same procedure, as per
    # http://docs.developer.amazonservices.com/en_US/feeds/Feeds_Overview.html
    # so we put a flag on the feed when it is done. The processing
    # of the feed itself is tracked in the amazon_mws_feeds

    # TODO: we could pass to the object some flags to filter out results.
    foreach my $feed (@$feeds) {
        # write out the feed if we got something to do, and add a row
        # to the feeds.

        # when there is no content, no need to create a job for it.
        if (my $content = $feed->{content}) {
            my $name = $feed->{name} or die "Missing feed_name";
            my $file = $self->_feed_file_for_method($job_id, $name);
            open (my $fh, '>', $file) or die "Couldn't open $file $!";
            print $fh $content;
            close $fh;
            # and prepare a row for it

            my $insertion = {
                             feed_name => $name,
                             feed_file => $file,
                             amws_job_id => $job_id,
                            };
            $self->_exe_query($self->sqla
                              ->insert(amazon_mws_feeds => $insertion));
        }
    }
    return $job_id;
}


sub resume {
    my $self = shift;
    my ($stmt, @bind) = $self->sqla->select(amazon_mws_jobs => '*', {
                                                                     aborted => 0,
                                                                     success => 0,
                                                                    });
    my $pending = $self->_exe_query($stmt, @bind);
    while (my $row = $pending->fetchrow_hashref) {
        # check if the job dir exists
        if (-d File::Spec->catdir($self->feed_dir, $row->{amws_job_id})) {
            $self->process_feeds($row);
        }
        else {
            my ($del_stmt, @del_bind) = $self->sqla
              ->delete(amazon_mws_jobs => { amws_job_id => $row->{amws_job_id} });
            $self->_exe_query($del_stmt, @del_bind);
        }
    }
}

=head2 process_feeds(\%job_row)

Given the hashref with the db row of the job, check at which point it
is and resume.

=cut

sub process_feeds {
    my ($self, $row) = @_;
    # print Dumper($row);
    # upload the feeds one by one and stop if something is blocking
    my $job_id = $row->{amws_job_id};
    print "Processing job $job_id\n";

    # query the feeds table for this job
    my ($stmt, @bind) = $self->sqla->select(amazon_mws_feeds => '*',
                                            {
                                             amws_job_id => $job_id,
                                             aborted => 0,
                                             success => 0,
                                            },
                                            ['amws_feed_pk']);

    my $sth = $self->_exe_query($stmt, @bind);
    my $unfinished;
    while (my $feed = $sth->fetchrow_hashref) {
        last unless $self->upload_feed($feed);
    }
    $sth->finish;

    ($stmt, @bind) = $self->sqla->select(amazon_mws_feeds => '*',
                                         {
                                          amws_job_id => $job_id,
                                         });

    $sth = $self->_exe_query($stmt, @bind);

    my ($total, $success, $aborted) = (0, 0, 0);

    # query again and check if we have aborted jobs;
    while (my $feed = $sth->fetchrow_hashref) {
        $total++;
        $success++ if $feed->{success};
        $aborted++ if $feed->{aborted};
    }

    # a job was aborted
    my $update;
    if ($aborted) {
        $update = { aborted => 1 };
        warn "Job $job_id aborted!\n";
    }
    elsif ($success == $total) {
        $update = { success => 1 };
        print "Job successful!\n";
        # if we're here, all the products are fine, so mark them as
        # such if it's an upload job
        if ($row->task eq 'upload') {
            $self->_exe_query($self->sqla->update('amazon_mws_products',
                                                  { status => 'ok'},
                                                  { amws_job_id => $job_id }));
        }
    }
    else {
        print "Job still to be processed\n";
    }
    if ($update) {
        $self->_exe_query($self->sqla->update(amazon_mws_jobs => $update,
                                              {
                                               amws_job_id => $job_id,
                                              }));
    }
}

=head2 upload_feed($type, $feed_id);

Routine to upload the feed. Return true if it's complete, false
otherwise.

=cut

sub upload_feed {
    my ($self, $record) = @_;
    my $job_id = $record->{amws_job_id};
    my $type   = $record->{feed_name};
    my $feed_id = $record->{feed_id};
    print "Checking $type feed for $job_id\n";
    # http://docs.developer.amazonservices.com/en_US/feeds/Feeds_FeedType.html


    my %names = (
                 product => '_POST_PRODUCT_DATA_',
                 inventory => '_POST_INVENTORY_AVAILABILITY_DATA_',
                 price => '_POST_PRODUCT_PRICING_DATA_',
                 image => '_POST_PRODUCT_IMAGE_DATA_',
                 variants => '_POST_PRODUCT_RELATIONSHIP_DATA_',
                 order_ack => '_POST_ORDER_ACKNOWLEDGEMENT_DATA_',
                );

    die "Unrecognized type $type" unless $names{$type};

    # no feed id, it's a new batch
    if (!$feed_id) {
        print "No feed id found, doing a request for $job_id $type\n";
        my $feed_content = $self->_slurp_file($record->{feed_file});
        my $res;
        try {
            $res = $self->client
              ->SubmitFeed(content_type => 'text/xml; charset=utf-8',
                           FeedType => $names{$type},
                           FeedContent => $feed_content,
                           MarketplaceIdList => [$self->marketplace_id],
                          );
        }
        catch {
            if (ref($_)) {
                if ($_->can('xml')) {
                    warn $_->xml;
                }
                else {
                    warn Dumper($_);
                }
            }
            else {
                warn $_;
            }
        };
        # do not register the failure on die, because in this case (no
        # response) there could be throttling, or network failure
        die unless $res;

        # update the feed_id row storing it and updating.
        if ($feed_id = $record->{feed_id} = $res->{FeedSubmissionId}) {
            $self->_exe_query($self->sqla
                              ->update(amazon_mws_feeds => $record,
                                       {
                                        amws_feed_pk => $record->{amws_feed_pk},
                                       }));
        }
        else {
            # something is really wrong here, we have to die
            die "Couldn't get a submission id, response is " . Dumper($res);
        }
    }
    print "Feed is $feed_id\n";

    if (!$record->{processing_complete}) {
        if ($self->_check_processing_complete($feed_id)) {
            # update the record and set the flag to true
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_feeds',
                                       { processing_complete => 1 },
                                       { feed_id => $feed_id }));
        }
        else {
            print "Still processing\n";
            return;
        }
    }

    # check if we didn't already processed it
    if (!$record->{aborted} || !$record->{success}) {
        # we need a class to parse the result.
        my $result = $self->submission_result($feed_id);
        if ($result->is_success) {
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_feeds',
                                       { success => 1 },
                                       { feed_id => $feed_id }));
            return 1;
        }
        else {
            warn "Error on feed $feed_id ($type) : " . $result->xml;
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_feeds',
                                       {
                                        aborted => 1,
                                        errors => $result->errors,
                                       },
                                       { feed_id => $feed_id }));
            # and we stop this job, has errors
            return 0;
        }
    }
    return $record->{success};
}

sub _exe_query {
    my ($self, $stmt, @bind) = @_;
    my $sth = $self->dbh->prepare($stmt);
    # print $stmt, Dumper(\@bind);
    $sth->execute(@bind);
    return $sth;
}

sub _check_processing_complete {
    my ($self, $feed_id) = @_;
    my $res;
    try {
        $res = $self->client->GetFeedSubmissionList;
    } catch {
        if (ref($_)) {
            warn $_->xml;
        }
        else {
            warn $_;
        }
    };
    die unless $res;
    print "Checking if the processing is complete\n"; # . Dumper($res);
    my $found;
    if (my $list = $res->{FeedSubmissionInfo}) {
        foreach my $feed (@$list) {
            if ($feed->{FeedSubmissionId} eq $feed_id) {
                $found = $feed;
                last;
            }
        }

        # check the result
        if ($found && $found->{FeedProcessingStatus} eq '_DONE_') {
            return 1;
        }
        elsif ($found) {
            print "Feed $feed_id still $found->{FeedProcessingStatus}\n";
            return;
        }
        else {
            # there is a remote possibility that in it in another
            # page, but it should be very unlikely, as we block the
            # process when the first one is not complete
            warn "$feed_id not found in submission list\n";
            return;
        }
    }
    else {
        warn "No FeedSubmissionInfo found:" . Dumper($res);
        return;
    }
}

sub submission_result {
    my ($self, $feed_id) = @_;
    my $xml;
    try {
        $xml = $self->client
          ->GetFeedSubmissionResult(FeedSubmissionId => $feed_id);
    } catch {
        warn $_->xml;
    };
    die unless $xml;
    return Amazon::MWS::XML::Response::FeedSubmissionResult->new(
                                                                 xml => $xml,
                                                                 schema_dir => $self->schema_dir,
                                                                );
}

=head2 get_orders($from_date)

This is a self-contained method and doesn't require a product list.
The from_date must be a L<DateTime> object. If not provided, it will
the last week.

Returns a list of Amazon::MWS::XML::Order objects.

=cut

sub get_orders {
    my ($self, $from_date) = @_;
    unless ($from_date) {
        $from_date = DateTime->now;
        $from_date->subtract(days => 7);
    }
    my $res;
    eval {
        $res = $self->client->ListOrders(
                                         MarketplaceId => [$self->marketplace_id],
                                         CreatedAfter  => $from_date,
                                        );
    };
    if (my $err = $@) {
        die Dumper($err);
    }
    my @orders;
    # TODO: there could be a next token thing to parse.
    die "tokens not implemented, fix the code"
      if $res->{HasNext} || $res->{NextToken};
    foreach my $order (@{ $res->{Orders}->{Order} }) {
        my $amws_id = $order->{AmazonOrderId};
        die "Missing amazon AmazonOrderId?!" unless $amws_id;

        # get the orderline
        my $orderline;
        eval {
            $orderline = $self->client->ListOrderItems(AmazonOrderId => $amws_id);
        };
        if (my $err = $@) {
            die Dumper($err);
        }
        die "tokens not implemented, fix the code"
          if $orderline->{HasNext} || $orderline->{NextToken};

        my $items = $orderline->{OrderItems}->{OrderItem};

        push @orders, Amazon::MWS::XML::Order->new(order => $order,
                                                   orderline => $items);
    }
    return @orders;
}

sub acknowledge_successful_order {
    my ($self, $order) = @_;
    my $feed_content = $self->acknowledge_feed($order);
    # here we have only one feed to upload and check
    $self->prepare_feeds(order_ack => [{
                                        name => 'order_ack',
                                        content => $feed_content,
                                       }]);
}

sub acknowledge_feed {
    my ($self, $order, $status) = @_;
    die "Missing order" unless $order;
    $status ||= 'Success';
    my $feeder = $self->generic_feeder;

    my $data = $order->as_ack_order_hashref;
    $data->{StatusCode} = $status;

    my $message = {
                   MessageID => 1,
                   OrderAcknowledgement => $data,
                  };
    return $feeder->create_feed(OrderAcknowledgement => [ $message ]);
}

sub delete_skus {
    my ($self, @skus) = @_;
    return unless @skus;
    my $feed_content = $self->delete_skus_feed(@skus);
    $self->prepare_feeds(product_deletion => [{
                                               name => 'product',
                                               content => $feed_content,
                                              }] );
}

sub delete_skus_feed {
    my ($self, @skus) = @_;
    return unless @skus;
    my $feeder = $self->generic_feeder;
    my $counter = 1;
    my @messages;
    foreach my $sku (@skus) {
        push @messages, {
                         MessageID => $counter++,
                         OperationType => 'Delete',
                         Product => {
                                     SKU => $sku,
                                    }
                        };
    }
    return $feeder->create_feed(Product => \@messages);
}


1;
