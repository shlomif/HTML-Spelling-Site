package HTML::Spelling::Site::Finder;

use strict;
use warnings;

use 5.014;

use MooX (qw( late ));

use File::Find::Object;

has 'prune_cb' => ( is => 'ro', isa => 'CodeRef', default => sub { return; } );
has 'root_dir' => ( is => 'ro', isa => 'Str', 'required' => 1, );

sub list_all_htmls
{
    my ($self) = @_;

    my $f = File::Find::Object->new( {}, $self->root_dir );

    my @got;
    while ( my $r = $f->next_obj() )
    {
        my $path = $r->path;
        if ( $self->prune_cb->($path) )
        {
            $f->prune;
        }
        elsif ( $r->is_file and $r->basename =~ /\.x?html\z/ )
        {
            push @got, $path;
        }
    }
    use locale;
    use POSIX qw(locale_h strtod);
    setlocale( LC_COLLATE, 'C' ) or die "cannot set locale.";

    return [ sort @got ];
}

1;

__END__

=head1 NAME

HTML::Spelling::Site::Finder - find the relevant .html/.xhtml files in
a directory tree.

=head1 SYNOPSIS

    use HTML::Spelling::Site::Finder;

    my $finder = HTML::Spelling::Site::Finder->new(
        {
            prune_cb => sub {
                return (shift =~ m#\Adest/blacklist/#);
            },
            root_dir => 'dest/',
        }
    );

    foreach my $html_file (@{$finder->list_all_htmls()})
    {
        print "Should check <$html_file>.\n";
    }

=head1 DESCRIPTION

The instances of this class can be used to scan a directory tree of files
ending with C<.html> and C<.xhtml> and to return a list of them as a sorted
array reference.

=head1 METHODS

=head2 ->new({ prune_cb => sub { ... }, root_dir => $root_dir })

Initialises a new object. C<prune_cb> is optional and C<root_dir> is required
and is the path to the root of the directory to scan.

=head2 my $array_ref = $finder->list_all_htmls()

Returns an array reference of all HTML files, sorted.

=head2 $finder->prune_cb()

Returns the prune callback. Mostly for internal use.

=head2 $finder->root_dir()

Returns the root directory.

=cut
