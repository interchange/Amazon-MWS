package Amazon::MWS::Exception;

=head1 NAME

Amazon::MWS::Exception

=head1 DESCRIPTION

Defines exceptions used by L<Amazon::MWS>:

=over 4

=item Amazon::MWS::Exception::MissingArgument

=item Amazon::MWS::Exception::Invalid

=item Amazon::MWS::Exception::Transport

=item Amazon::MWS::Exception::Response

=item Amazon::MWS::Exception::BadChecksum

=item Amazon::MWS::Exception::Throttled

=back

=cut

use Exception::Class (
    Amazon::MWS::Exception,
    "Amazon::MWS::Exception::MissingArgument" => {
        isa    => Amazon::MWS::Exception,
        fields => 'name',
        alias  => 'arg_missing',
        description => 'Missing argument (see name)',
    },
    "Amazon::MWS::Exception::Invalid" => {
        isa    => Amazon::MWS::Exception,
        fields => [qw(field value message)],
	alias  => 'list_error', 
        description => 'Invalid list passed (see field, value, message)',
    },
    "Amazon::MWS::Exception::Transport" => {
        isa    => Amazon::MWS::Exception,
        fields => [qw(request response)],
        alias  => 'transport_error',
        description => 'Transport error (see response)',
    },
    "Amazon::MWS::Exception::Response" => {
        isa    => Amazon::MWS::Exception,
        fields => [qw(errors xml)],
        alias  => 'error_response',
        description => 'Response error (see xml)',
    },
    "Amazon::MWS::Exception::BadChecksum" => {
        isa    => Amazon::MWS::Exception,
        fields => 'request',
        alias  => 'bad_checksum',
        description => 'Bad Checksum',
    },
    "Amazon::MWS::Exception::Throttled" => {
        isa    => Amazon::MWS::Exception,
        fields => [qw(errors xml)],
        alias  => 'throttled',
        description => 'Request is throttled',
    },

);

1;
