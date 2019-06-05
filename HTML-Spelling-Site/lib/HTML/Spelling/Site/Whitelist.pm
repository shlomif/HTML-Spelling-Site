package HTML::Spelling::Site::Whitelist;

use strict;
use warnings;
use autodie;

use 5.014;

use MooX (qw( late ));

use IO::All qw/ io /;

has '_general_whitelist' => ( is => 'ro', default => sub { return []; } );
has '_records'           => ( is => 'ro', default => sub { return []; } );
has '_general_hashref' => ( is => 'ro', default => sub { return +{}; } );
has '_per_file'        => ( is => 'ro', default => sub { return +{}; } );
has '_was_parsed'      => ( is => 'rw', default => '' );
has 'filename' => ( is => 'ro', isa => 'Str', required => 1 );

sub check_word
{
    my ( $self, $args ) = @_;

    my $filename = $args->{filename};
    my $word     = $args->{word};

    return (
               exists( $self->_general_hashref->{$word} )
            or exists( $self->_per_file->{$filename}->{$word} )
    );
}

sub parse
{
    my ($self) = @_;

    if ( !$self->_was_parsed() )
    {

        my $rec;
        open my $fh, '<:encoding(utf8)', $self->filename;
        my $found_global = 0;
        while ( my $l = <$fh> )
        {
            chomp($l);

            # Whitespace or comment - skip.
            if ( $l !~ /\S/ or ( $l =~ /\A\s*#/ ) )
            {
                # Do nothing.
            }
            elsif ( $l =~ s/\A====\s+// )
            {
                if ( $l =~ /\AGLOBAL:\s*\z/ )
                {
                    if ( defined($rec) )
                    {
                        die "GLOBAL is not the first directive.";
                    }
                    $found_global = 1;
                }
                elsif ( $l =~ /\AIn:\s*(.*)/ )
                {
                    my @filenames = split /\s*,\s*/, $1;

                    if ( defined($rec) )
                    {
                        push @{ $self->_records }, $rec;
                    }

                    my %found;
                    foreach my $fn (@filenames)
                    {
                        if ( exists $found{$fn} )
                        {
                            die
"Filename <<$fn>> appears twice in line <<=== In: $l>>";
                        }
                        $found{$fn} = 1;
                    }
                    $rec = {
                        'files' => [ sort { $a cmp $b } @filenames ],
                        'words' => [],
                        },
                        ;
                }
                else
                {
                    die "Unknown directive <<==== $l>>!";
                }
            }
            else
            {
                if ( defined($rec) )
                {
                    push @{ $rec->{'words'} }, $l;
                }
                else
                {
                    if ( !$found_global )
                    {
                        die "GLOBAL not found before first word.";
                    }
                    push @{ $self->_general_whitelist }, $l;
                }
            }
        }
        if ( defined $rec )
        {
            push @{ $self->_records }, $rec;
        }
        close($fh);

        foreach my $w ( @{ $self->_general_whitelist } )
        {
            $self->_general_hashref->{$w} = 1;
        }

        foreach my $rec ( @{ $self->_records } )
        {
            my @lists;
            foreach my $fn ( @{ $rec->{files} } )
            {
                push @lists, ( $self->_per_file->{$fn} //= +{} );
            }

            foreach my $w ( @{ $rec->{words} } )
            {
                foreach my $l (@lists)
                {
                    $l->{$w} = 1;
                }
            }
        }
    }
    $self->_was_parsed(1);

    return;
}

sub _rec_sorter
{
    my ( $a_aref, $b_aref, $idx ) = @_;

    return (
          ( @$a_aref == $idx ) ? -1
        : ( @$b_aref == $idx ) ? 1
        : ( ( $a_aref->[$idx] cmp $b_aref->[$idx] )
                || _rec_sorter( $a_aref, $b_aref, $idx + 1 ) )
    );
}

sub _sort_words
{
    my $words_aref = shift;

    return [ sort { $a cmp $b } @$words_aref ];
}

sub get_sorted_text
{
    my ($self) = @_;

    $self->parse;

    my %_gen = map { $_ => 1 } @{ $self->_general_whitelist };

    return join '', map { "$_\n" } (
        "==== GLOBAL:",
        '',
        @{ _sort_words( [ keys %_gen ] ) },
        (
            map {
                my %found;
                (
                    '',
                    ( "==== In: " . join( ' , ', @{ $_->{files} } ) ),
                    '',
                    (
                        @{
                            _sort_words(
                                [
                                    grep {
                                                !exists( $_gen{$_} )
                                            and !( $found{$_}++ )
                                    } @{ $_->{words} }
                                ]
                            )
                        }
                    )
                )
                }
                sort { _rec_sorter( $a->{files}, $b->{files}, 0 ) }
                @{ $self->_records }
        )
    );
}

sub _get_io
{
    my ($self) = @_;

    return io->encoding('utf8')->file( $self->filename );
}

sub is_sorted
{
    my ($self) = @_;

    $self->parse;

    return ( $self->_get_io->all eq $self->get_sorted_text );
}

sub write_sorted_file
{
    my ($self) = @_;

    $self->parse;

    $self->_get_io->print( $self->get_sorted_text );

    return;
}

1;

=head1 NAME

HTML::Spelling::Site::Whitelist - handles the whitelist file.

=head1 SYNOPSIS

    use HTML::Spelling::Site::Whitelist;

    my $obj = HTML::Spelling::Site::Whitelist->new(
        {
            filename => 'path/to/whitelist.txt',
        }
    );

    $obj->parse;

    if (! $obj->check_word('clover'))
    {
        # Do more spell checking.
    }

    $obj->write_sorted_file;

=head1 DESCRIPTION

The instances of this class can be used to manage a whitelist of words to
spell check.

=head1 METHODS

=head2 my $obj = HTML::Spelling::Site::Checker->new({ filename => './path/to/whitelist.txt'});

Initialises a new object. C<filename> is the path to the file.

=head2 $whitelist->parse;

For now you should call this method right after the object is created.

=head2 $finder->check_word({filename => $filename, word => $word})

Checks if the word $word in the file $filename is in the whitelist.

=head2 $finder->write_sorted_file;

Rewrites the file to be sorted and canonicalized.

=head2 $finder->is_sorted();

Checks if the file is properly sorted and canonicalized.

=head2 $finder->get_sorted_text()

Returns the sorted text of the whitelist.

=head2 $finder->filename()

Returns the filename.

=head1 WHITELIST FORMAT

The format of the whitelist file is:

    ==== GLOBAL:

    [Global whitelist with one word per line]

    ==== In: path1 , path2 , path3

    [one word per line whitelist for path1, path2 and path3]

    ==== In: path4

    [one word per line whitelist for path4]

(B<NOTE> that the paths are a complete path to the file and not parsed for
wildcards or regular expression syntax.)

Here's another example:

L<https://bitbucket.org/shlomif/shlomi-fish-homepage/src/493302cc5f1d81584f6f21bbd64197048e185aa6/lib/hunspell/whitelist1.txt?at=default&fileviewer=file-view-default>

You should keep the whitelist file canonicalised and sorted by using
write_sorted_file() and is_sorted() .

=cut

