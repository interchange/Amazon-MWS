package Amazon::MWS::Feeds;

use Amazon::MWS::Routines qw(:all);

my $version = '2009-01-01';

=head1 NAME

Amazon::MWS::Feeds - API methods for feeds

=head1 API methods

=over 4

=item SubmitFeed

=item GetFeedSubmissionList

=item GetFeedSubmissionListByNextToken

=item GetFeedSubmissionCount

=item CancelFeedSubmissions

=item GetFeedSubmissionResult

=back

=head1 Authors

=over 4

=item Marco Pessotto

=item Phil Smith

=item Stefan Hornburg (Racke)

=back

=head1 License

This is free software; you can redistribute it and/or modify it under the same terms
as the Perl 5 programming language system itself.

=cut

define_api_method SubmitFeed =>
    version => "$version",
    parameters => {
        MarketplaceIdList => {
             required   =>      0,
             type       =>      'IdList',
        },
        FeedContent => {
            required => 1,
            type     => 'HTTP-BODY',
        },
        FeedType => {
            required => 1,
            type     => 'string',
        },
        PurgeAndReplace => {
            type     => 'boolean',
        },
    },
    respond => sub {
        my $root = shift->{FeedSubmissionInfo};
        convert($root, SubmittedDate => 'datetime');
        return $root;
    };

define_api_method GetFeedSubmissionList =>
    version => "$version",
    parameters => {
        FeedSubmissionIdList     => { type => 'IdList' },
        MaxCount                 => { type => 'nonNegativeInteger' },
        FeedTypeList             => { type => 'TypeList' },
        FeedProcessingStatusList => { type => 'StatusList' },
        SubmittedFromDate        => { type => 'datetime' },
        SubmittedToDate          => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
        convert($root, HasNext => 'boolean');
        Amazon::MWS::Reports::convert_FeedSubmissionInfo($root);
        return $root;
    };

define_api_method GetFeedSubmissionListByNextToken =>
    version => "$version",
    parameters => { 
        NextToken => {
            type     => 'string',
            required => 1,
        },
    },
    respond => sub {
        my $root = shift;
        convert($root, HasNext => 'boolean');
        Amazon::MWS::Reports::convert_FeedSubmissionInfo($root);

        return $root;
    };

define_api_method GetFeedSubmissionCount =>
    version => "$version",
    parameters => {
        FeedTypeList             => { type => 'TypeList' },
        FeedProcessingStatusList => { type => 'StatusList' },
        SubmittedFromDate        => { type => 'datetime' },
        SubmittedToDate          => { type => 'datetime' },
    },
    respond => sub { $_[0]->{Count} };

define_api_method CancelFeedSubmissions =>
    version => "$version",
    parameters => {
        FeedSubmissionIdList => { type => 'IdList' },
        FeedTypeList         => { type => 'TypeList' },
        SubmittedFromDate    => { type => 'datetime' },
        SubmittedToDate      => { type => 'datetime' },
    },
    respond => sub {
        my $root = shift;
        Amazon::MWS::Reports::convert_FeedSubmissionInfo($root);
        return $root;
    };

define_api_method GetFeedSubmissionResult =>
    version => "$version",
    raw_body   => 1,
    parameters => {
        FeedSubmissionId => { 
            type     => 'string',
            required => 1,
        },
    };

1;
