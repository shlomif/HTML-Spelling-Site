package HTML::Spelling::Site;

use strict;
use warnings;

use 5.014;

1;

__END__

=head1 NAME

HTML::Spelling::Site - a system/framework for spell-checking an entire static
HTML site.

=head1 SYNOPSIS

See L<HTML::Spelling::Site::Checker> .

And also see the example code on L<https://bitbucket.org/shlomif/shlomi-fish-homepage> .

=head1 DESCRIPTION

HTML::Spelling::Site was created in order to consolidate and extract the
duplicate functionality for spell checking my web-sites. Currently
documentation is somewhat lacking and the modules could use some extra
automated tests, but I'm anxious to get something out the door.

=head1 SEE ALSO

L<Test::HTML::Spelling> - possibly somewhat less generic than
HTML::Spelling::Site and can also only handle one file at the time. Note that
I contributed a little to it, but only after I started working on the code
that became this framework.

=cut
