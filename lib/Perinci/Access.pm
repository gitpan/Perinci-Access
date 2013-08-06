package Perinci::Access;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

use Scalar::Util qw(blessed);
use URI;

our $Log_Request  = $ENV{LOG_RIAP_REQUEST}  // 0;
our $Log_Response = $ENV{LOG_RIAP_RESPONSE} // 0;

our $VERSION = '0.33'; # VERSION

sub new {
    my ($class, %opts) = @_;

    $opts{handlers}               //= {};
    $opts{handlers}{riap}         //= 'Perinci::Access::InProcess';
    $opts{handlers}{pl}           //= 'Perinci::Access::InProcess';
    $opts{handlers}{http}         //= 'Perinci::Access::HTTP::Client';
    $opts{handlers}{https}        //= 'Perinci::Access::HTTP::Client';
    $opts{handlers}{'riap+tcp'}   //= 'Perinci::Access::Simple::Client';
    $opts{handlers}{'riap+unix'}  //= 'Perinci::Access::Simple::Client';
    $opts{handlers}{'riap+pipe'}  //= 'Perinci::Access::Simple::Client';

    my @schemes = keys %{$opts{handlers}};
    for (@schemes) {
        next if /\A(riap|pl|http|https|riap\+tcp|riap\+unix|riap\+pipe)\z/;
        $log->warnf("Unknown Riap scheme %s", $_);
    }

    $opts{_handler_objs}          //= {};
    bless \%opts, $class;
}

# convert URI string into URI object
sub _normalize_uri {
    my ($self, $uri) = @_;

    $uri //= "";

    return $uri if blessed($uri);
    if ($uri =~ /^\w+(::\w+)+$/) {
        # assume X::Y is a module name
        my $orig = $uri;
        $uri =~ s!::!/!g;
        $uri = "/$uri/";

        #return URI->new("pl:$uri");

        # to avoid mistakes, die instead
        die "You specified module name '$orig' as Riap URI, ".
            "please use '$uri' instead";
    } else {
        return URI->new(($uri =~ /\A[A-Za-z+-]+:/ ? "" : "pl:") . $uri);
    }
}

sub request {
    my ($self, $action, $uri, $extra, $copts) = @_;

    $uri = $self->_normalize_uri($uri);
    my $sch = $uri->scheme;
    die "Unrecognized scheme '$sch' in URL" unless $self->{handlers}{$sch};

    # convert riap:// to pl:/ as InProcess only accepts the later
    if ($sch eq 'riap') {
        print $uri->path;
        my ($host) = $uri =~ m!//([^/]+)!; # host() not supported, URI::_foreign
        if ($host =~ /^(?:perl|pl)$/) {
            $uri = URI->new("pl:" . $uri->path);
        } else {
            die "Unsupported host '$host' in riap: scheme, ".
                "only 'perl' is supported";
        }
    }

    unless ($self->{_handler_objs}{$sch}) {
        if (blessed($self->{handlers}{$sch})) {
            $self->{_handler_objs}{$sch} = $self->{handlers}{$sch};
        } else {
            my $modp = $self->{handlers}{$sch};
            $modp =~ s!::!/!g; $modp .= ".pm";
            require $modp;
            #$log->tracef("TMP: Creating Riap client object for schema %s with args %s", $sch, $self->{handler_args});
            $self->{_handler_objs}{$sch} = $self->{handlers}{$sch}->new(
                %{ $self->{handler_args} // {}});
        }
    }

    if ($Log_Request && $log->is_trace) {
        $log->tracef(
            "Riap request (%s): %s -> %s (%s)",
            ref($self->{_handler_objs}{$sch}), $action, "$uri", $extra, $copts);
    }
    my $res = $self->{_handler_objs}{$sch}->request($action,$uri,$extra,$copts);
    if ($Log_Response && $log->is_trace) {
        $log->tracef("Riap response: %s", $res);
    }
    $res;
}

1;
# ABSTRACT: Wrapper for Perinci Riap clients

__END__

=pod

=head1 NAME

Perinci::Access - Wrapper for Perinci Riap clients

=head1 VERSION

version 0.33

=head1 SYNOPSIS

 use Perinci::Access;

 my $pa = Perinci::Access->new;
 my $res;

 # use Perinci::Access::InProcess
 $res = $pa->request(call => "pl:/Mod/SubMod/func");

 # ditto
 $res = $pa->request(call => "/Mod/SubMod/func");

 # use Perinci::Access::HTTP::Client
 $res = $pa->request(info => "http://example.com/Sub/ModSub/func",
                     {uri=>'/Sub/ModSub/func'});

 # use Perinci::Access::Simple::Client
 $res = $pa->request(meta => "riap+tcp://localhost:7001/Sub/ModSub/");

 # dies, unknown scheme
 $res = $pa->request(call => "baz://example.com/Sub/ModSub/");

=head1 DESCRIPTION

This module provides a convenient wrapper to select appropriate Riap client
(Perinci::Access::*) objects based on URI scheme (or lack thereof).

 riap://perl/Foo/Bar/  -> Perinci::Access::InProcess
 /Foo/Bar/             -> Perinci::Access::InProcess
 pl:/Foo/Bar           -> Perinci::Access::InProcess
 http://...            -> Perinci::Access::HTTP::Client
 https://...           -> Perinci::Access::HTTP::Client
 riap+tcp://...        -> Perinci::Access::Simple::Client
 riap+unix://...       -> Perinci::Access::Simple::Client
 riap+pipe://...       -> Perinci::Access::Simple::Client

For more details on each scheme, please consult the appropriate module.

You can customize or add supported schemes by providing class name or object to
the B<handlers> attribute (see its documentation for more details).

=head1 VARIABLES

=head2 $Log_Request (BOOL)

Whether to log every Riap request. Default is from environment variable
LOG_RIAP_REQUEST, or false. Logging is done with L<Log::Any> at trace level.

=head2 $Log_Response (BOOL)

Whether to log every Riap response. Default is from environment variable
LOG_RIAP_RESPONSE, or false. Logging is done with L<Log::Any> at trace level.

=head1 METHODS

=head2 new(%opts) -> OBJ

Create new instance. Known options:

=over 4

=item * handlers => HASH

A mapping of scheme names and class names or objects. If values are class names,
they will be require'd and instantiated. The default is:

 {
   riap         => 'Perinci::Access::InProcess',
   pl           => 'Perinci::Access::InProcess',
   http         => 'Perinci::Access::HTTP::Client',
   https        => 'Perinci::Access::HTTP::Client',
   'riap+tcp'   => 'Perinci::Access::Simple::Client',
   'riap+unix'  => 'Perinci::Access::Simple::Client',
   'riap+pipe'  => 'Perinci::Access::Simple::Client',
 }

Objects can be given instead of class names. This is used if you need to pass
special options when instantiating the class.

=item * handler_args => HASH

Arguments to pass to handler objects' constructors.

=back

=head2 $pa->request($action, $server_url, \%extra, \%copts) -> RESP

Send Riap request to Riap server. Pass the request to the appropriate Riap
client (as configured in C<handlers> constructor options). RESP is the enveloped
result.

C<%extra> is optional, containing Riap request keys (the C<action> request key
 is taken from C<$action>).

C<%copts> is optional, containing Riap-client-specific options. For example, to
pass HTTP credentials to C<Perinci::Access::HTTP::Client>, you can do:

 $pa->request(call => 'http://example.com/Foo/bar', {args=>{a=>1}},
              {user=>'admin', password=>'secret'});

=head1 ENVIRONMENT

LOG_RIAP_REQUEST

LOG_RIAP_RESPONSE

=head1 SEE ALSO

L<Perinci::Access::InProcess>

L<Perinci::Access::HTTP::Client>

L<Perinci::Access::Simple::Client>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut