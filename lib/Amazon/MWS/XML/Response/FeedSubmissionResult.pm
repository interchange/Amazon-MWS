package Amazon::MWS::XML::Response::FeedSubmissionResult;

use strict;
use warnings;
use XML::Compile::Schema;
use Data::Dumper;

use Moo;
use namespace::clean;

=head1 NAME

Amazon::MWS::XML::Response::FeedSubmissionResult -- response parser

=head1 SYNOPSIS

  my $res = Amazon::MWS::XML::Response::FeedSubmissionResult->new(xml => $xml);
  if ($res->is_success) { ... };

=head1 ACCESSOR

=head2 xml

The xml string

=head2 structure

Lazy attribute built via parsing the xml string passed at the constructor.

=head1 METHODS

=head2 is_success

=head2 errors

=cut

has xml => (is => 'ro', required => '1');
has schema_dir => (is => 'ro',
                   required => 1,
                   isa => sub {
                       die "Not a dir" unless -d $_[0];
                   });


has structure => (is => 'lazy');

sub _build_structure {
    my $self = shift;
    my $files = File::Spec->catfile($self->schema_dir, '*.xsd');
    my $schema = XML::Compile::Schema->new([glob $files]);
    my $reader = $schema->compile(READER => 'AmazonEnvelope');
    my $struct = $reader->($self->xml);
    die "not a processing report xml" unless $struct->{MessageType} eq 'ProcessingReport';
    if (@{$struct->{Message}} > 1) {
        die $self->xml . " returned more than 1 message!";
    }
    return $struct->{Message}->[0]->{ProcessingReport};
}

has skus_errors => (is => 'lazy');
has skus_warnings => (is => 'lazy');

sub _build_skus_errors {
    my $self = shift;
    return $self->_parse_results('Error');
}

sub _build_skus_warnings {
    my $self = shift;
    return $self->_parse_results('Warning');
}

sub _parse_results {
    my ($self, $code) = @_;
    die unless ($code eq 'Error' or $code eq 'Warning');
    my $struct = $self->structure;
    my @msgs;
    if ($struct->{Result}) {
        foreach my $res (@{ $struct->{Result} }) {
            if ($res->{ResultCode} and $res->{ResultCode} eq $code) {
                if (my $sku = $res->{AdditionalInfo}->{SKU}) {
                    push @msgs, {
                                   sku => $sku,
                                   # this is a bit misnamed, but not too much
                                   error => $res->{ResultDescription} || '',
                                   code => $res->{ResultMessageCode} || '',
                                  };
                }
                else {
                    push @msgs, {
                                 error => $res->{ResultDescription} || '',
                                 code => $res->{ResultMessageCode} || '',
                                };
                }
            }
        }
    }
    @msgs ? return \@msgs : return;
}



sub is_success {
    my $self = shift;
    my $struct = $self->structure;
    if ($struct->{StatusCode} eq 'Complete') {
        # Compute the total - successful
        my $success = $struct->{ProcessingSummary}->{MessagesSuccessful};
        my $error   = $struct->{ProcessingSummary}->{MessagesWithError};
        # we ignore the warnings here.
        # my $warning = $struct->{ProcessingSummary}->{MessagesWithWarning};
        my $total   = $struct->{ProcessingSummary}->{MessagesProcessed};
        if (!$error and $total == $success) {
            return 1;
        }
    }
    return;
}

sub warnings {
    my $self = shift;
    return $self->_format_msgs($self->skus_warnings);
}

sub errors {
    my $self = shift;
    return $self->_format_msgs($self->skus_errors);
}

sub _format_msgs {
    my ($self, $list) = @_;
    if ($list && @$list) {
        my @errors;
        foreach my $err (@$list) {
            if ($err->{sku}) {
                push @errors, "$err->{sku}: $err->{error} ($err->{code})";
            }
            else {
                push @errors, "$err->{error} ($err->{code})";
            }
        }
        return join("\n", @errors);
    }
    return;
}

sub failed_skus {
    my ($self) = @_;
    return $self->_list_faulty_skus($self->skus_errors);
}

sub skus_with_warnings {
    my ($self) = @_;
    return $self->_list_faulty_skus($self->skus_warnings);
}

sub _list_faulty_skus {
    my ($self, $list) = @_;
    if ($list && @$list) {
        return map { $_->{sku} } @$list;
    }
    else {
        return;
    }
}



1;
