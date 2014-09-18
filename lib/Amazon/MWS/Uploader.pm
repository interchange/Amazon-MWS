package Amazon::MWS::Uploader;

use strict;
use warnings;

use DBI;
use Amazon::MWS::XML::Feed;
use Amazon::MWS::Client;
use Amazon::MWS::XML::Response::FeedSubmissionResult;
use Data::Dumper;
use File::Spec;
use DateTime;
use SQL::Abstract;

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

sub _feed_content_for_method {
    my ($self, $job_id, $feed_type) = @_;
    my $file = $self->_feed_file_for_method($job_id, $feed_type);
    open (my $fh, '<', $file) or die "Couldn't open $file $!";
    local $/ = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}


sub upload {
    my $self = shift;
    # first create the job id, using the current time
    my $job_id = DateTime->now->strftime('%F-%H-%M');
    # create the feeds to be uploaded using the products
    my $feeder = $self->feeder;
    # to be extended
    
    foreach my $feed_type (qw/product
                              inventory
                             /) {
        my $file = $self->_feed_file_for_method($job_id, $feed_type);
        my $method = $feed_type . "_feed";
        open (my $fh, '>', $file) or die "Couldn't open $file $!";
        print $fh $feeder->$method ;
        close $fh;
    }
    $self->_exe_query($self->sqla
                      ->insert(amazon_mws_jobs => {
                                                   amws_job_id => $job_id,
                                                  }));
    $self->resume;
}


sub resume {
    my $self = shift;
    my ($stmt, @bind) = $self->sqla->select(amazon_mws_jobs => '*', [
                                                                     aborted => 0,
                                                                     success => 0,
                                                                    ]);
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
    foreach my $type (qw/product inventory/) {
        if (!$row->{$type. "_ok"}) {
            last unless $self->upload_feed($row->{amws_job_id},
                                           $type,
                                           $row->{$type});
        }
    }
}

=head2 upload_feed($type, $feed_id);

Routine to upload the feed. Return true if it's complete, false
otherwise.

=cut

sub upload_feed {
    my ($self, $job_id, $type, $feed_id) = @_;

    my %names = (
                 product => '_POST_PRODUCT_DATA_',
                 inventory => '_POST_INVENTORY_AVAILABILITY_DATA_',
                );

    # no feed id, it's a new batch
    if (!$feed_id) {
        warn "No feed id passed, doing a request for $job_id $type\n";
        my $feed_content = $self->_feed_content_for_method($job_id, $type);
        my $res = $self->client
          ->SubmitFeed(content_type => 'text/xml; charset=utf-8',
                       FeedType => $names{$type},
                       FeedContent => $feed_content,
                      );
        if ($feed_id = $res->{FeedSubmissionId}) {
            my $insertion = {
                             amws_feed_id => $feed_id,
                             feed_name => $names{$type},
                             feed_file => $self->_feed_file_for_method($job_id,
                                                                       $type),
                             amws_job_id => $job_id,
                            };
            $self->_exe_query($self->sqla
                              ->insert(amazon_mws_feeds => $insertion));
            # and update the job to hold it
            $self->_exe_query($self->sqla
                              ->update(amazon_mws_jobs => { $type => $feed_id },
                                       { amws_job_id => $job_id }));
        }
        else {
            # something is really wrong here, we have to die
            die "Couldn't get a submission id, response is " . Dumper($res);
        }
    }
    warn "Feed is is $feed_id\n";

    # At this point, we need to know if it's processed
    my $feed_sth = $self->_exe_query($self->sqla
                                     ->select(amazon_mws_feeds => '*',
                                              { amws_feed_id => $feed_id }));
    my $record = $feed_sth->fetchrow_hashref;
    # for now let's die
    die "This shouldn't happen, no record for $feed_id" unless $record;
    $feed_sth->finish;

    if (!$record->{processing_complete}) {
        if ($self->_check_processing_complete($feed_id)) {
            # update the record and set the flag to true
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_feeds',
                                       { processing_complete => 1 },
                                       { amws_feed_id => $feed_id }));
        }
        else {
            warn "Still processing\n";
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
                                       { amws_feed_id => $feed_id }));
            # all good, update the job itself and set it tu success
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_jobs',
                                       { "${type}_ok" => 1 },
                                       { amws_job_id => $job_id }));
            return 1;
        }
        else {
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_feeds',
                                       {
                                        aborted => 1,
                                        errors => $result->errors,
                                       },
                                       { amws_feed_id => $feed_id }));
            # no go, we got errors
            $self->_exe_query($self->sqla
                              ->update('amazon_mws_jobs',
                                       {
                                        aborted => 1,
                                       },
                                       { amws_job_id => $job_id }));

            # and we stop this job, has errors
            return 0;
        }
    }
    return $record->{success};
}

sub _exe_query {
    my ($self, $stmt, @bind) = @_;
    my $sth = $self->dbh->prepare($stmt);
    $sth->execute(@bind);
    return $sth;
}

sub _check_processing_complete {
    my ($self, $feed_id) = @_;
    my $res = $self->client->GetFeedSubmissionList;
    warn "Checking if the processing is complete\n"; # . Dumper($res);
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
            warn "Feed $feed_id still $found->{FeedProcessingStatus}\n";
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
    my $xml = $self->client->GetFeedSubmissionResult(FeedSubmissionId => $feed_id);
    return Amazon::MWS::XML::Response::FeedSubmissionResult->new(xml => $xml);
}

1;
