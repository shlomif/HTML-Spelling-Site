package HTML::Spelling::Site::Checker;

use strict;
use warnings;
use autodie;
use utf8;

use MooX qw/late/;

use HTML::Parser 3.00 ();
use List::MoreUtils qw(any);
use JSON::MaybeXS qw(decode_json);
use IO::All qw/ io /;

has '_inside' => (is => 'rw', isa => 'HashRef', default => sub { return +{};});
has 'whitelist_parser' => (is => 'ro', required => 1);
has 'check_word_cb' => (is => 'ro', isa => 'CodeRef', required => 1);
has 'timestamp_cache_fn' => (is => 'ro', isa => 'Str', required => 1);

sub _tag
{
    my ($self, $tag, $num) = @_;

    $self->_inside->{$tag} += $num;

    return;
}

sub spell_check
{
    my ($self, $args) = @_;

    my $filenames = $args->{files};

    my $whitelist = $self->whitelist_parser;
    $whitelist->parse;

    binmode STDOUT, ":encoding(utf8)";

    my $calc_cache_io = sub {
        return io->file($self->timestamp_cache_fn);
    };

    my $app_key = 'HTML-Spelling-Site';
    my $data_key = 'timestamp_cache';

    my $write_cache = sub {
        my $ref = shift;
        $calc_cache_io->()->print(
            JSON::MaybeXS->new(canonical => 1)->encode(
                {
                    $app_key =>
                    {
                        $data_key => $ref,
                    },
                },
            )
        );

        return;
    };

    if (! $calc_cache_io->()->exists())
    {
        $write_cache->(+{});
    }

    my $timestamp_cache = decode_json(scalar($calc_cache_io->()->slurp()))->{$app_key}->{$data_key};

    my $check_word = $self->check_word_cb;

    FILENAMES_LOOP:
    foreach my $filename (@$filenames)
    {
        if (exists($timestamp_cache->{$filename}) and
            $timestamp_cache->{$filename} >= (io->file($filename)->mtime())
        )
        {
            next FILENAMES_LOOP;
        }

        my $file_is_ok = 1;

        my $process_text = sub
        {
            if (any {
                    exists($self->_inside->{$_}) and $self->_inside->{$_} > 0
                } qw(script style))
            {
                return;
            }

            my $text = shift;

            my @lines = split /\n/, $text, -1;

            foreach my $l (@lines)
            {

                my $mispelling_found = 0;

                my $mark_word = sub {
                    my ($word) = @_;

                    $word =~ s{’(ve|s|m|d|t|ll|re)\z}{'$1};
                    $word =~ s{[’']\z}{};
                    if ($word =~ /[A-Za-z]/)
                    {
                        $word =~ s{\A(?:(?:ֹו?(?:ש|ל|מ|ב|כש|לכש|מה|שה|לכשה|ב-))|ו)-?}{};
                        $word =~ s{'?ים\z}{};
                    }

                    my $verdict =
                    (
                        (! $whitelist->check_word({filename => $filename, word => $word}))
                        &&
                        ($word !~ m#\A[\p{Hebrew}\-'’]+\z#)
                        &&
                        (!($check_word->($word)))
                    );

                    $mispelling_found ||= $verdict;

                    return $verdict ? "«$word»" : $word;
                };

                $l =~ s/
                # Not sure this regex to match a word is fully
                # idiot-proof, but we can amend it later.
                ([\w'’-]+)
                /$mark_word->($1)/egx;

                if ($mispelling_found)
                {
                    $file_is_ok = 0;
                    printf {*STDOUT}
                    (
                        "%s:%d:%s\n",
                        $filename,
                        1,
                        $l
                    );
                }
            }
        };

        open(my $fh, "<:utf8", $filename);

        HTML::Parser->new(api_version => 3,
            handlers    => [start => [sub { return $self->_tag(@_); }, "tagname, '+1'"],
                end   => [sub { return $self->_tag(@_); }, "tagname, '-1'"],
                text  => [$process_text, "dtext"],
            ],
            marked_sections => 1,
        )->parse_file($fh);

        close ($fh);

        if ($file_is_ok)
        {
            $timestamp_cache->{$filename} = io->file($filename)->mtime();
        }
    }

    $write_cache->($timestamp_cache);

    print "\n";

    return;
}

1;

__END__

=head1 NAME

HTML::Spelling::Site::Checker - does the actual checking.

=head1 SYNOPSIS

    TODO - FILL IN.

=head1 DESCRIPTION

The instances of this class can be used to do the actual scanning of
local HTML files.

=head1 METHODS

=head2 my $obj = HTML::Spelling::Site::Checker->new({ whitelist_parser => $parser_obj, check_word_cb => sub { ... }, timestamp_cache_fn => '/path/to/timestamp-cache.json' })

Initialises a new object. C<whitelist_parser> is normally an instance of
L<HTML::Spelling::Site::Whitelist>. C<check_word_cb> is a subroutine to check
a word for correctness. C<timestamp_cache_fn> points to the path where the
cache of the last-checked timestamps of the files is stored in JSON format.

=head2 $finder->spell_check();

Performs the spell check and prints the erroneous words to stdout.

=head2 $finder->whitelist_parser()

For internal use.

=head2 $finder->check_word_cb()

For internal use.

=head2 $finder->timestamp_cache_fn()

For internal use.

=cut

