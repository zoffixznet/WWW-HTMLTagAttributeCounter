package WWW::HTMLTagAttributeCounter;

use warnings;
use strict;

# VERSION

use LWP::UserAgent;
use HTML::TokeParser::Simple;
use overload q|""| => sub { shift->result_readable };

use base 'Class::Accessor::Grouped';
__PACKAGE__->mk_group_accessors( simple => qw/
    ua
    result
    error
/);

sub new {
    my ( $class, %args ) = @_;

    $args{ua} ||= LWP::UserAgent->new(
        timeout => 30,
        agent   => 'Opera 9.5',
    );

    my $self = bless {}, $class;
    $self->ua( $args{ua} );

    return $self;
}

sub count {
    my ( $self, $where, $what, $type, ) = @_;

    $self->$_(undef)
        for qw/error result/;

    $what = [ $what ]
        unless ref $what eq 'ARRAY';

    defined $type
        or $type = 'tag';

    my $content;
    if ( ref $where eq 'SCALAR' ) {
        $content = $$where;
    }
    else {
        $where =~ m{^https?://}
            or $where = "http://$where";

        my $response = $self->ua->get( $where );

        $response->is_success
            or return $self->_set_error( $response );

        $content = $response->decoded_content;
    }

    return $self->result( $self->_count( $what, $type, $content ) );
}

sub result_readable {
    my $result = shift->result;

    my @out;
    for ( sort keys %$result ) {
        push @out, "$result->{$_} $_";
    }

    return $out[0]
        if @out == 1;

    return (join q|, |, @out[0..$#out-1]) . ' and ' . $out[-1];
}

sub _count {
    my ( $self, $what, $type, $content ) = @_;

    my $p = HTML::TokeParser::Simple->new( \$content );
    my $count = {};
    while ( my $t = $p->get_token ) {
        next
            unless $t->is_start_tag;

        if ( $type eq 'tag' ) {
            for ( @$what ) {
                $t->is_start_tag($_)
                    and $count->{$_}++;
            }
        }
        elsif ( $type eq 'attr') {
            for ( @$what ) {
                defined $t->get_attr($_)
                    and $count->{$_}++;
            }
        }
    }

    defined $count->{$_}
        or $count->{$_} = 0
            for @$what;

    return $count;
}

sub _set_error {
    my ( $self, $response ) = @_;
    $self->error('Network error: ' . $response->status_line );
    return;
}

1;
__END__

=encoding utf8

=for stopwords webpage arrayref hashref parsable IRC

=head1 NAME

WWW::HTMLTagAttributeCounter - access a webpage and count number of tags or attributes

=head1 SYNOPSIS

=for pod_spiffy start code section

    use strict;
    use warnings;

    use WWW::HTMLTagAttributeCounter;

    my $c = WWW::HTMLTagAttributeCounter->new;

    $c->count('zoffix.com', [ qw/a span div/ ] )
        or die "Error: " . $c->error . "\n";

    print "I counted $c tags on zoffix.com\n";

=for pod_spiffy end code section

=head1 DESCRIPTION

The module was developed for use in an IRC bot thus you may find it useless for anything else.

The module simply accesses a given webpage and counts either HTML tags or HTML element
attributes.

=head1 CONSTRUCTOR

=head2 C<new>

=for pod_spiffy in key value | out object

    my $c = WWW::HTMLTagAttributeCounter->new;

    my $c = WWW::HTMLTagAttributeCounter->new(
        ua => LWP::UserAgent->new( timeout => 10 ),
    );

Contructs and returns a fresh C<WWW::HTMLTagAttributeCounter> object. Takes the following
arguments in a key/value fashion:

=head3 C<ua>

=for pod_spiffy in object

    my $c = WWW::HTMLTagAttributeCounter->new(
        ua => LWP::UserAgent->new( timeout => 10 ),
    );

B<Optional>. The C<ua> argument takes an L<LWP::UserAgent>-like object as a value, the object
must have a C<get()> method that returns L<HTTP::Response> object and takes a URI to fetch
as the first argument. B<Default to:>

    LWP::UserAgent->new(
        timeout => 30,
        agent   => 'Opera 9.5',
    );

=head1 METHODS

=head2 C<count>

=for pod_spiffy in scalar or arrayref | out hashref

    my $result = $c->count( 'http://zoffix.com/', 'div' )
        or die $c->error;

    my $result = $c->count( 'http://zoffix.com/', [ qw/div span a/ ] )
        or die $c->error;

    my $result = $c->count( 'http://zoffix.com/', [ qw/href class id/ ], 'attr' )
        or die $c->error;

Instructs the object to count tags or attributes. Takes two or three arguments that are as
follows:

=head3 first argument

    $c->count( 'http://zoffix.com/', 'div' )

    $c->count( \ '<div></div><div></div>, 'div' )

B<Mandatory>.
The first argument must be either a string with URI to access or a B<reference> to a scalar
containing the actual HTML code. If the URI is passed the object will fetch the URI and
the contents of will be treated as HTML code.

=head3 second argument

    $c->count( 'http://zoffix.com/', 'div' )

    $c->count( 'http://zoffix.com/', [ qw/div span a/ ] )

    $c->count( 'http://zoffix.com/', 'href', 'attr' )

    $c->count( 'http://zoffix.com/', [ qw/href id class/ ], 'attr' )

B<Mandatory>. The second argument takes either a string or an arrayref as a value. Specifying
a string is the same as specifying an arrayref with just that string in it. The argument
represents what to count, i.e. this would be either tag names or attribute names.

=head3 third argument

    $c->count( 'http://zoffix.com/', 'div' )

    $c->count( 'http://zoffix.com/', 'div', 'tag' )

    $c->count( 'http://zoffix.com/', 'href', 'attr' )

B<Optional>. The third argument (if specified) must be either string C<tag> or string
C<attr>. The argument specifies what to count, if it's C<tag> then the object will count
tags (specified in the second argument) if the value is C<attr> then the object will
count attributes. B<Defaults to:> C<tag>

=head3 return value

    my $result = $c->count( 'http://zoffix.com/', [ qw/div a span/ ], )
        or die $c->error;

    $VAR1 = {
        'div' => 6,
        'a' => 15,
        'span' => 8
    };

In case of an error the C<count()> method returns either C<undef> or an empty list,
depending on the context, and the description of the error will be available via C<error()>
method. On success returns a hashref where keys are either tags or attributes that you
were counting and values are the actual count numbers.

=head2 C<result>

=for pod_spiffy in no args | out hashref

    $c->count( 'http://zoffix.com/', [ qw/div a span/ ], )
        or die $c->error;

    my $result = $c->result;

Must be called after a successful call to C<count()> method. Returns the exact same hashref
last call to C<count()> method returned.

=head2 C<result_readable>

=for pod_spiffy in no args | out scalar

    $c->count( 'http://zoffix.com/', [ qw/div a span/ ], )
        or die $c->error;

    print "I counted $c tags on zoffix.com\n";
    # or
    print "I counted " . $c->result_readable . " tags on zoffix.com\n"
    ## prints:   I counted 15 a, 6 div and 8 span tags on zoffix.com

Must be called after a successful call to C<count()> method. Returns count results as
a string, e.g.:

    15 a, 6 div and 8 span
    6 div and 8 span
    8 span

This method is overloaded on C<"">, therefore you can simply use the object in a string to
get the return of this method.

=head2 C<error>

=for pod_spiffy in no args | out scalar

    $c->count( 'http://zoffix.com/', [ qw/div a span/ ], )
        or die $c->error;

If C<count()> method fails it will return either C<undef> or an empty list, depending on the
context, and the error will be available via C<error()> method. Takes no arguments, returns
human parsable error message explaing the failure.

=head2 C<ua>

=for pod_spiffy in object | out object

    my $ua = $c->ua;
    $ua->proxy( 'http', 'http://foo.com' );
    $c->ua( $ua );

Returns currently used object that used for fetching URIs - see constructor's C<ua> argument
for details. Takes one optional argument - the new object to use for fetching.

=for pod_spiffy hr

=head1 REPOSITORY

=for pod_spiffy start github section

Fork this module on GitHub:
L<https://github.com/zoffixznet/WWW-HTMLTagAttributeCounter>

=for pod_spiffy end github section

=head1 BUGS

=for pod_spiffy start bugs section

To report bugs or request features, please use
L<https://github.com/zoffixznet/WWW-HTMLTagAttributeCounter/issues>

If you can't access GitHub, you can email your request
to C<bug-www-htmltagattributecounter at rt.cpan.org>

=for pod_spiffy end bugs section

=head1 AUTHOR

=for pod_spiffy start author section

=for pod_spiffy author ZOFFIX

=for text Zoffix Znet <zoffix at cpan.org>

=for pod_spiffy end author section

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut

