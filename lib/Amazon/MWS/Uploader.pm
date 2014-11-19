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
use MooX::Types::MooseLike::Base qw(:all);
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
                   isa => AnyOf[Undef,HashRef],
                  );
has dbh => (is => 'lazy');


=item order_days_range

When calling get_orders, check the orders for the last X days. It
accepts an integer which should be in the range 1-30. Defaults to 30.

=cut

has order_days_range => (is => 'rw',
                         default => sub { 30 },
                         isa => sub {
                             my $days = $_[0];
                             die "Not an integer"
                               unless is_Int($days);
                             die "$days is out of range 1-30"
                               unless $days > 0 && $days < 31;
                         });

=item shop_id

You can pass an arbitrary identifier to the constructor which will be
used to keep the database records separated if you have multiple
amazon accounts. If not provided, the merchant id will be used, which
will work, but it's harder (for the humans) to spot and debug.

=cut

has shop_id => (is => 'ro');

has _unique_shop_id => (is => 'lazy');

sub _build__unique_shop_id {
    my $self = shift;
    if (my $id = $self->shop_id) {
        return $id;
    }
    else {
        return $self->merchant_id;
    }
}

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

=item purge_missing_products

If true, the first time C<products_to_upload> is called, products not
passed to the C<products> constructor will be purged from the
C<amazon_mws_products> table. Default to false.

=cut

has purge_missing_products => (is => 'ro');


=item reset_all_errors

If set to a true value, don't skip previously failed items and
effectively reset all of them.

=cut

has reset_all_errors => (is => 'ro');

=item reset_errors

A string containing a comma separated list of error codes, optionally
prefixed with a "!" (to reverse its meaning).

Example:

  "!6024,6023"

Meaning: reupload all the products whose error code is B<not> 6024 or
6023.

  "6024,6023"

Meaning: reupload the products whose error code was 6024 or 6023

=cut

has reset_errors => (is => 'ro',
                     isa => sub {
                         my $string = $_[0];
                         # undef/0/'' is fine
                         if ($string) {
                             die "reset_errors must be a comma separated list of error code, optionally prefixed by a '!' to negate its meaning"
                               if $string !~ m/^\s*!?\s*(([0-9]+)(\s*,\s*)?)+/;
                         }
                     });


has _reset_error_structure => (is => 'lazy');

sub _build__reset_error_structure {
    my $self = shift;
    my $reset_string = $self->reset_errors || '';
    $reset_string =~ s/^\s*//;
    $reset_string =~ s/\s*$//;
    return unless $reset_string;

    my $negate = 0;
    if ($reset_string =~ m/^\s*!\s*(.+)/) {
        $reset_string = $1;
        $negate = 1;
    }
    my %codes = map { $_ => 1 } grep { $_ } split(/\s*,\s*/, $reset_string);
    return unless %codes;
    return {
            negate => $negate,
            codes  => \%codes,
           };
}


=item force

Same as above, but only for the selected items. An arrayref is
expected here with the B<skus>.

=cut

has force => (is => 'ro',
              isa => ArrayRef,
             );


has _force_hashref => (is => 'lazy');

sub _build__force_hashref {
    my $self = shift;
    my %forced;
    if (my $arrayref = $self->force) {
        %forced = map { $_ => 1 } @$arrayref;
    }
    return \%forced;
}

=item limit_inventory

If set to an integer, limit the inventory to this value. Setting this
to 0 will disable it.

=cut

has limit_inventory => (is => 'ro',
                        isa => Int);

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

=cut

has products => (is => 'rw',
                 isa => ArrayRef);

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
                                                                               error_code
                                                                              /],
                                                    {
                                                     shop_id => $self->_unique_shop_id,
                                                    }));
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
    return [] unless $product_arrayref && @$product_arrayref;
    my @products = @$product_arrayref;
    my $existing = $self->existing_products;
    my @todo;
    foreach my $product (@products) {
        my $sku = $product->sku;
        if (my $exists = $existing->{$sku}) {
            # mark the item as visited
            $exists->{_examined} = 1;
            # skip already uploaded products with the same timestamp string.
            my $status = $exists->{status} || '';
            if ($status eq 'ok') {
                if ($exists->{timestamp_string} eq ($product->timestamp_string || 0)) {
                    print "Skipping already uploaded item $sku \n";
                    next;
                }
            }
            elsif ($status eq 'redo') {
                print "Redoing $sku\n";
            }
            elsif ($status eq 'failed') {
                if ($self->reset_all_errors || $self->_force_hashref->{$sku}) {
                    print "Resetting error for $sku\n";
                }
                elsif (my $reset = $self->_reset_error_structure) {
                    # option for this error was passed.
                    my $error = $exists->{error_code};
                    my $match = $reset->{codes}->{$error};
                    if (($match && $reset->{negate}) or
                        (!$match && !$reset->{negate})) {
                        # was passed !this error or !random , so do not reset
                        print "Skipping failed item $sku with error code $error\n";
                        next;
                    }
                    else {
                        # otherwise reset
                        print "Resetting error for $sku with error code $error\n";
                    }
                }
                else {
                    print "Skipping failed item $sku\n";
                    next;
                }
            }
            elsif ($status) {
                # something else is going on. Pending or failed
                print "Skipping $exists->{status} item $sku\n";
                next;
            }
        }
        print "Scheduling product " . $product->sku . " for upload\n";
        if (my $limit = $self->limit_inventory) {
            my $real = $product->inventory;
            if ($real > $limit) {
                print "Limiting the $sku inventory from $real to $limit\n";
                $product->inventory($limit);
            }
        }
        if (my $children = $product->children) {
            my @good_children;
            foreach my $child (@$children) {
                if ($existing->{$child} and
                    $existing->{$child}->{status} eq 'failed') {
                    print "Ignoring failed variant $child\n";
                }
                else {
                    push @good_children, $child;
                }
            }
            $product->children(\@good_children);
        }
        push @todo, $product;
    }
    if ($self->purge_missing_products) {
        # nuke the products not passed
        # print Dumper($existing);
        my @deletions = map { $_->{sku} }
          grep { !$_->{_examined} }
            values %$existing;
        if (@deletions) {
            print "Purging missing items " . join(" ", @deletions) . "\n";
            $self->delete_skus(@deletions);
        }
    }
    return \@todo;
}


=item client

An L<Amazon::MWS::Client> object, built lazily, so you don't have to
pass it.

=back

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

sub _feed_job_dir {
    my ($self, $job_id) = @_;
    die unless $job_id;
    my $shop_id = $self->_unique_shop_id;
    $shop_id =~ s/[^0-9A-Za-z_-]//g;
    die "The shop id without word characters results in an empty string"
      unless $shop_id;
    my $feed_root = File::Spec->catdir($self->feed_dir,
                                       $shop_id);
    mkdir $feed_root unless -d $feed_root;

    my $feed_subdir = File::Spec->catdir($feed_root,
                                         $job_id);
    mkdir $feed_subdir unless -d $feed_subdir;
    return $feed_subdir;
}

sub _feed_file_for_method {
    my ($self, $job_id, $feed_type) = @_;
    die unless $job_id && $feed_type;
    my $feed_subdir = $self->_feed_job_dir($job_id);
    my $file = File::Spec->catfile($feed_subdir, $feed_type . '.xml');
    return File::Spec->rel2abs($file);
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

    # at the end of this method, we insert them anew marking them as
    # pending
    $self->_remove_products_from_table(@products);
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

sub _remove_products_from_table {
    my ($self, @products) = @_;
    return unless @products;
    my @skus = map { $_->sku } @products;
    # delete those skus from the db, we will insert them again aftward
    $self->_exe_query($self->sqla->delete('amazon_mws_products',
                                          {
                                           sku => { -in => \@skus },
                                           shop_id => $self->_unique_shop_id,
                                          }));
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
                                                                      shop_id => $self->_unique_shop_id,
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
                                                   shop_id => $self->_unique_shop_id,
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
                             shop_id => $self->_unique_shop_id,
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
                                                                     shop_id => $self->_unique_shop_id,
                                                                    });
    my $pending = $self->_exe_query($stmt, @bind);
    while (my $row = $pending->fetchrow_hashref) {
        # check if the job dir exists
        if (-d $self->_feed_job_dir($row->{amws_job_id})) {
            $self->process_feeds($row);
        }
        else {
            warn "No directory " . $self->_feed_job_dir($row->{amws_job_id}) .
              " found, removing job id $row->{amws_job_id}\n";
            my ($del_stmt, @del_bind) = $self->sqla
              ->delete(amazon_mws_jobs => {
                                           amws_job_id => $row->{amws_job_id},
                                           shop_id => $self->_unique_shop_id,
                                          });
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
                                             shop_id => $self->_unique_shop_id,
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
                                          shop_id => $self->_unique_shop_id,
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
        if ($row->{task} eq 'upload') {
            $self->_exe_query($self->sqla->update('amazon_mws_products',
                                                  { status => 'ok',
                                                    listed_date => DateTime->now},
                                                  {
                                                   amws_job_id => $job_id,
                                                   shop_id => $self->_unique_shop_id,
                                                  }));
        }
    }
    else {
        print "Job still to be processed\n";
    }
    if ($update) {
        $self->_exe_query($self->sqla->update(amazon_mws_jobs => $update,
                                              {
                                               amws_job_id => $job_id,
                                               shop_id => $self->_unique_shop_id,
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
                 shipping_confirmation => '_POST_ORDER_FULFILLMENT_DATA_',
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
            warn "Failure to submit $type feed: \n";
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
                                        shop_id => $self->_unique_shop_id,
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
                                       {
                                        feed_id => $feed_id,
                                        shop_id => $self->_unique_shop_id,
                                       }));
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
                                       {
                                        feed_id => $feed_id,
                                        shop_id => $self->_unique_shop_id,
                                       }));
            # if we have a success, print the warnings on the stderr.
            # if we have a failure, the warnings will just confuse us.

            if ($type eq 'order_ack') {
                # flip the confirmation bit
                $self->_exe_query($self->sqla->update(amazon_mws_orders => { confirmed => 1 },
                                                      { amws_job_id => $job_id,
                                                        shop_id => $self->_unique_shop_id }));
            }
            elsif ($type eq 'shipping_confirmation') {
                $self->_exe_query($self->sqla->update(amazon_mws_orders => { shipping_confirmation_ok => 1 },
                                                      { shipping_confirmation_job_id => $job_id,
                                                        shop_id => $self->_unique_shop_id }));
            }
            if (my $warn = $result->warnings) {
                warn "$warn\n";
            }
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
                                       {
                                        feed_id => $feed_id,
                                        shop_id => $self->_unique_shop_id,
                                       }));
            $self->register_errors($job_id, $result);
            
            if ($type eq 'order_ack') {
                $self->_exe_query($self->sqla->update(amazon_mws_orders => { error_msg => $result->errors },
                                                      { amws_job_id => $job_id,
                                                        shop_id => $self->_unique_shop_id }));
            }
            elsif ($type eq 'shipping_confirmation') {
                $self->_exe_query($self->sqla->update(amazon_mws_orders => { shipping_confirmation_error => $result->errors },
                                                      { shipping_confirmation_job_id => $job_id,
                                                        shop_id => $self->_unique_shop_id }));
            }
            
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
            print "$feed_id not found in submission list\n";
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
        my $exception = $_;
        if (ref($exception) && $exception->can('xml')) {
            warn "submission result error: " . $exception->xml;
        }
        else {
            warn "submission result error: " . Dumper($exception);
        }
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
        $from_date->subtract(days => $self->order_days_range);
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

=head2 order_already_registered($order)

Check in the amazon_mws_orders table if we already registered this
order.

Return the row for this table (as an hashref) if present, nothing
underwise.

=cut

sub order_already_registered {
    my ($self, $order) = @_;
    die "Bad usage, missing order" unless $order;
    my $sth = $self->_exe_query($self->sqla->select(amazon_mws_orders => '*',
                                                    {
                                                     amazon_order_id => $order->amazon_order_number,
                                                     shop_id => $self->_unique_shop_id,
                                                    }));
    if (my $exists = $sth->fetchrow_hashref) {
        $sth->finish;
        return $exists;
    }
    else {
        return;
    }
}

sub acknowledge_successful_order {
    my ($self, @orders) = @_;
    my @orders_to_register;
    foreach my $ord (@orders) {
        if (my $existing = $self->order_already_registered($ord)) {
            if ($existing->{confirmed}) {
                print "Skipping already confirmed order $existing->{amazon_order_id} => $existing->{shop_order_id}\n";
            }
            else {
                # it's not complete, so print out diagnostics
                warn "Order $existing->{amazon_order_id} uncompletely registered with id $existing->{shop_order_id}, please indagate why (skipping)\n" . Dumper($existing);
            }
        }
        else {
            push @orders_to_register, $ord;
        }
    }
    return unless @orders_to_register;

    my $feed_content = $self->acknowledge_feed(Success => @orders_to_register);
    # here we have only one feed to upload and check
    my $job_id = $self->prepare_feeds(order_ack => [{
                                                     name => 'order_ack',
                                                     content => $feed_content,
                                                    }]);
    # store the pairing amazon order id / shop order id in our table
    foreach my $order (@orders_to_register) {
        my %order_pairs = (
                           shop_id => $self->_unique_shop_id,
                           amazon_order_id => $order->amazon_order_number,
                           # this will die if we try to insert an undef order_number
                           shop_order_id => $order->order_number,
                           amws_job_id => $job_id,
                          );
        $self->_exe_query($self->sqla->insert(amazon_mws_orders => \%order_pairs));
    }
}

sub acknowledge_feed {
    my ($self, $status, @orders) = @_;
    die "Missing status" unless $status;
    die "Missing orders" unless @orders;

    my $feeder = $self->generic_feeder;

    my $counter = 1;
    my @messages;
    foreach my $order (@orders) {
        my $data = $order->as_ack_order_hashref;
        $data->{StatusCode} = $status;
        push @messages, {
                         MessageID => $counter++,
                         OrderAcknowledgement => $data,
                        };
    }
    return $feeder->create_feed(OrderAcknowledgement => \@messages);
}

sub delete_skus {
    my ($self, @skus) = @_;
    return unless @skus;
    my $feed_content = $self->delete_skus_feed(@skus);
    $self->prepare_feeds(product_deletion => [{
                                               name => 'product',
                                               content => $feed_content,
                                              }] );
    # delete the skus locally
    $self->_exe_query($self->sqla->delete('amazon_mws_products',
                                          {
                                           sku => { -in => \@skus },
                                           shop_id => $self->_unique_shop_id,
                                          }));
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

sub register_errors {
    my ($self, $job_id, $result) = @_;
    # first, get the list of all the skus which were scheduled for this job
    # we don't have a products hashref anymore.
    # probably we could parse back the produced xml, but looks like an overkill.
    # just mark them as redo and wait for the next cron call.
    my @products = $self->skus_in_job($job_id);
    my $errors = $result->skus_errors;
    my @errors_with_sku = grep { $_->{sku} } @$errors;
    # turn it into an hash
    my %errs = map { $_->{sku} => {job_id => $job_id, code => $_->{code}, error => $_->{error}} } @errors_with_sku;

    foreach my $sku (@products) {
        if ($errs{$sku}) {
            $self->_exe_query($self->sqla->update('amazon_mws_products',
                                                  {
                                                   status => 'failed',
                                                   error_code => $errs{$sku}->{code},
                                                   error_msg => "$errs{$sku}->{job_id} $errs{$sku}->{code} $errs{$sku}->{error}",
                                                  },
                                                  {
                                                   sku => $sku,
                                                   shop_id => $self->_unique_shop_id,
                                                  }));
        }
        else {
            # this is good, mark it to be redone
            $self->_exe_query($self->sqla->update('amazon_mws_products',
                                                  {
                                                   status => 'redo',
                                                  },
                                                  {
                                                   sku => $sku,
                                                   shop_id => $self->_unique_shop_id,
                                                  }));
            print "Scheduling $sku for redoing\n";
        }
    }
}

sub skus_in_job {
    my ($self, $job_id) = @_;
    my $sth = $self->_exe_query($self->sqla->select('amazon_mws_products',
                                                    [qw/sku/],
                                                    {
                                                     amws_job_id => $job_id,
                                                     shop_id => $self->_unique_shop_id,
                                                    }));
    my @skus;
    while (my $row = $sth->fetchrow_hashref) {
        push @skus, $row->{sku};
    }
    return @skus;
}

=head2 get_asin_for_eans(@eans)

Accept a list of EANs and return an hashref where the keys are the
eans passed as arguments, and the values are the ASIN for the current
marketplace. Max EANs: 5.x

http://docs.developer.amazonservices.com/en_US/products/Products_GetMatchingProductForId.html

=head2 get_asin_for_ean($ean)

Same as above, but for a single ean. Return the ASIN or undef if not
found.

=cut

sub get_asin_for_eans {
    my ($self, @eans) = @_;
    my $client = $self->client;
    die "too many eans passed (max 5)" if @eans > 5;
    my $res = $client->GetMatchingProductForId(IdType => 'EAN',
                                               IdList => \@eans,
                                               MarketplaceId => $self->marketplace_id);
    my %ids;
    if ($res && @$res) {
        foreach my $product (@$res) {
            $ids{$product->{Id}} = $product->{Products}->{Product}->{Identifiers}->{MarketplaceASIN}->{ASIN};
        }
    }
    return \%ids;
}

sub get_asin_for_ean {
    my ($self, $ean) = @_;
    my $res = $self->get_asin_for_eans($ean);
    if ($res && $res->{$ean}) {
        return $res->{$ean};
    }
    else {
        return;
    }
}

=head2 get_product_categories($ean)

Return a list of category codes (the ones passed to
RecommendedBrowseNode) which exists on amazon.

=cut

sub get_product_categories {
    my ($self, $ean) = @_;
    return unless $ean;
    my $asin = $self->get_asin_for_ean($ean);
    unless ($asin) {
        return;
    }
    my $res = $self->client
      ->GetProductCategoriesForASIN(ASIN => $asin,
                                    MarketplaceId => $self->marketplace_id);
    if ($res) {
        my @ids = map { $_->{ProductCategoryId} } @$res;
        return @ids;
    }
    else {
        warn "ASIN exists but no categories found. Bug?\n";
        return;
    }
}


# http://docs.developer.amazonservices.com/en_US/products/Products_GetLowestOfferListingsForSKU.html

=head2 get_lowest_price_for_asin($asin, $condition)

Return the lowest price for asin, excluding ourselves. The second
argument, condition, is optional and defaults to "New".

If you need the full details, you have to call
$self->client->GetLowestOfferListingsForASIN yourself and make sense
of the output. This method is mostly a wrapper meant to simplify the
routine.

If we can't get any info, just return undef.

Return undef if no prices are found.

=head2 get_lowest_price_for_ean($ean, $condition)

Same as above, but use the EAN instead

=cut

sub get_lowest_price_for_ean {
    my ($self, $ean, $condition) = @_;
    return unless $ean;
    my $asin = $self->get_asin_for_ean($ean);
    return unless $asin;
    return $self->get_lowest_price_for_asin($asin, $condition);
}

sub get_lowest_price_for_asin {
    my ($self, $asin, $condition) = @_;
    die "Wrong usage, missing argument asin" unless $asin;
    my $listing = $self->client
      ->GetLowestOfferListingsForASIN(
                                      ASINList => [ $asin ],
                                      MarketplaceId => $self->marketplace_id,
                                      ExcludeMe => 1,
                                      ItemCondition => $condition || 'New',
                                     );
    return unless $listing && @$listing;
    my $lowest;
    foreach my $item (@$listing) {
        my $current = $item->{Price}->{LandedPrice}->{Amount};
        $lowest ||= $current;
        if ($current < $lowest) {
            $lowest = $current;
        }
    }
    return $lowest;
}

=head2 shipping_confirmation_feed(@shipped_orders)

Return a feed string with the shipping confirmation. A list of
L<Amazon::MWS::XML::ShippedOrder> object must be passed.

=cut

sub shipping_confirmation_feed {
    my ($self, @shipped_orders) = @_;
    die "Missing Amazon::MWS::XML::ShippedOrder argument" unless @shipped_orders;
    my $feeder = $self->generic_feeder;
    my $counter = 1;
    my @messages;
    foreach my $order (@shipped_orders) {
        push @messages, {
                         MessageID => $counter++,
                         OrderFulfillment => $order->as_shipping_confirmation_hashref,
                        };
    }
    return $feeder->create_feed(OrderFulfillment => \@messages);

}

=head2 send_shipping_confirmation($shipped_orders)

Schedule the shipped orders (an L<Amazon::MWS::XML::ShippedOrder>
object) for the uploading.

=head2 order_already_shipped($shipped_order)

Check if the shipped orders (an L<Amazon::MWS::XML::ShippedOrder> was
already notified as shipped looking into our table, returning the row
with the order.

To see the status, check shipping_confirmation_ok (already done),
shipping_confirmation_error (faulty), shipping_confirmation_job_id (pending).

=cut

sub order_already_shipped {
    my ($self, $order) = @_;
    my $condition = $self->_condition_for_shipped_orders($order);
    my $sth = $self->_exe_query($self->sqla->select(amazon_mws_orders => '*', $condition));
    if (my $row = $sth->fetchrow_hashref) {
        die "Multiple results found in amazon_mws_orders for " . Dumper($condition)
          if $sth->fetchrow_hashref;
        return $row;
    }
    else {
        return;
    }
}

sub send_shipping_confirmation {
    my ($self, @orders) = @_;
    my @orders_to_notify;
    foreach my $ord (@orders) {
        if (my $report = $self->order_already_shipped($ord)) {
            if ($report->{shipping_confirmation_ok}) {
                print "Skipping ship-confirm for order $report->{amazon_order_id} $report->{shop_order_id}: already notified\n";
            }
            elsif (my $error = $report->{shipping_confirmation_error}) {
                warn "Skipping ship-confirm for order $report->{amazon_order_id} $report->{shop_order_id} with error $error\n";
            }
            elsif ($report->{shipping_confirmation_job_id}) {
                print "Skipping ship-confirm for order $report->{amazon_order_id} $report->{shop_order_id}: pending\n";
            }
            else {
                push @orders_to_notify, $ord;
            }
        }
        else {
            die "It looks like you are trying to send a shipping confirmation "
              . " without prior order acknowlegdement. "
                . "At least in the amazon_mws_orders there is no trace of "
                  . "$report->{amazon_order_id} $report->{shop_order_id}";
        }
    }
    return unless @orders_to_notify;
    my $feed_content = $self->shipping_confirmation_feed(@orders_to_notify);
    # here we have only one feed to upload and check
    my $job_id = $self->prepare_feeds(shipping_confirmation => [{
                                                                 name => 'shipping_confirmation',
                                                                 content => $feed_content,
                                                                }]);
    # and store the job id in the table
    foreach my $ord (@orders_to_notify) {
        $self->_exe_query($self->sqla->update(amazon_mws_orders => {
                                                                    shipping_confirmation_job_id => $job_id,
                                                                   },
                                              $self->_condition_for_shipped_orders($ord)));
    }
}

sub _condition_for_shipped_orders {
    my ($self, $order) = @_;
    die "Missing order" unless $order;
    my %condition = (shop_id => $self->_unique_shop_id);
    if (my $amazon_order_id = $order->amazon_order_id) {
        $condition{amazon_order_id} = $amazon_order_id;
    }
    elsif (my $order_id = $order->merchant_order_id) {
        $condition{shop_order_id} = $order_id;
    }
    else {
        die "Missing amazon_order_id or merchant_order_id";
    }
    return \%condition;
}


=head2 orders_waiting_for_shipping

Return a list of hashref with two keys, C<amazon_order_id> and
C<shop_order_id> for each order which is waiting confirmation.

This is implemented looking into amazon_mws_orders where there is no
shipping confirmation job id but there is the confirmed flag (which
means we acknowledged the order).

=cut

sub orders_waiting_for_shipping {
    my $self = shift;
    my $sth = $self->_exe_query($self->sqla->select('amazon_mws_orders',
                                                    [qw/amazon_order_id
                                                        shop_order_id/],
                                                    {
                                                     shop_id => $self->_unique_shop_id,
                                                     shipping_confirmation_job_id => undef,
                                                     confirmed => 1,
                                                    }));
    my @out;
    while (my $row = $sth->fetchrow_hashref) {
        push @out, $row;
    }
    return @out;
}


1;
