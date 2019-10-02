# This module is responsible for generating elm/Gen/*.
#
# It exports an `elm_form` function to generate type definitions, a JSON
# encoder and HTML5 validation attributes to simplify and synchronize forms.
#
# It also exports an `elm_Response` function for each possible API response
# (see %apis below).

package VNWeb::Elm;

use strict;
use warnings;
use TUWF;
use Exporter 'import';
use List::Util 'max';
use VNDB::Config;
use VNDB::Types;
use VNWeb::Auth;

our @EXPORT = qw/
    elm_form
/;


# API response types and arguments. To generate an API response from Perl, call
# elm_ResponseName(@args), e.g.:
#
#   elm_Changed $id, $revision;
#
# These API responses are available in Elm in the `Gen.Api.Response` union type.
my %apis = (
    Unauth         => [], # Not authorized
    Unchanged      => [], # No changes
    Changed        => [ { id => 1 }, { uint => 1 } ], # [ id, chrev]; DB entry has been successfully changed
    Success        => [],
    CSRF           => [], # Invalid CSRF token
    Invalid        => [], # POST data did not validate the schema
    Content        => [{}], # Rendered HTML content (for markdown/bbcode APIs)
    BadLogin       => [], # Invalid user or pass
    LoginThrottle  => [], # Too many failed login attempts
    InsecurePass   => [], # Password is in a dictionary or breach database
    BadEmail       => [], # Unknown email address in password reset form
    Bot            => [], # User didn't pass bot verification
    Taken          => [], # Username already taken
    DoubleEmail    => [], # Account with same email already exists
    DoubleIP       => [], # Account with same IP already exists
    BadCurPass     => [], # Current password is incorrect when changing password
);


# Generate the elm_Response() functions
for my $name (keys %apis) {
    no strict 'refs';
    $apis{$name} = [ map tuwf->compile($_), $apis{$name}->@* ];
    *{'elm_'.$name} = sub {
        my @args = map {
            $apis{$name}[$_]->validate($_[$_])->data if tuwf->debug;
            $apis{$name}[$_]->analyze->coerce_for_json($_[$_], unknown => 'reject')
        } 0..$#{$apis{$name}};
        tuwf->resJSON({$name, \@args})
    };
    push @EXPORT, 'elm_'.$name;
}




# Formatting functions
sub indent($) { $_[0] =~ s/\n/\n  /gr }
sub list      { indent "\n[ ".join("\n, ", @_)."\n]" }
sub string($) { '"'.($_[0] =~ s/([\\"])/\\$1/gr).'"' }
sub tuple     { '('.join(', ', @_).')' }
sub bool($)   { $_[0] ? 'True' : 'False' }
sub to_camel  { (ucfirst $_[0]) =~ s/_([a-z])/'_'.uc $1/egr; }

# Generate a variable definition: name, type, value
sub def($$$)  { sprintf "\n%s : %s\n%1\$s = %s\n", @_; }


# Generate an Elm type definition corresponding to a TUWF::Validate schema
sub def_type {
    my($name, $obj) = @_;
    my $data = '';
    my @keys = $obj->{keys} ? grep $obj->{keys}{$_}{keys}||($obj->{keys}{$_}{values}&&$obj->{keys}{$_}{values}{keys}), sort keys $obj->{keys}->%* : ();

    $data .= def_type($name . to_camel($_), $obj->{keys}{$_}{values} || $obj->{keys}{$_}) for @keys;

    $data .= sprintf "\ntype alias %s = %s\n\n", $name, $obj->elm_type(
        keys => +{ map +($_, ($obj->{keys}{$_}{values} ? 'List ' : '') . $name . to_camel($_)), @keys }
    );
    $data
}


# Generate HTML5 validation attribute lists corresponding to a TUWF::Validate schema
# TODO: Deduplicate some regexes (weburl, email)
# TODO: Throw these inside a struct for better namespacing?
sub def_validation {
    my($name, $obj) = @_;
    $obj = $obj->{values} if $obj->{values};
    my $data = '';

    $data .= def_validation($name . to_camel($_), $obj->{keys}{$_}) for $obj->{keys} ? sort keys $obj->{keys}->%* : ();

    my %v = $obj->html5_validation();
    $data .= def $name, 'List (Html.Attribute msg)', '[ '.join(', ',
        $v{required}  ? 'A.required True' : (),
        $v{minlength} ? "A.minlength $v{minlength}" : (),
        $v{maxlength} ? "A.maxlength $v{maxlength}" : (),
        $v{min}       ? 'A.min '.string($v{min}) : (),
        $v{max}       ? 'A.max '.string($v{max}) : (),
        $v{pattern}   ? 'A.pattern '.string($v{pattern}) : ()
    ).']' if !$obj->{keys};
    $data;
}


# Generate an Elm JSON encoder taking a corresponding def_type() as input
sub encoder {
    my($name, $type, $obj) = @_;
    def $name, "$type -> JE.Value", $obj->elm_encoder(json_encode => 'JE.');
}




sub write_module {
    my($module, $contents) = @_;
    my $fn = sprintf '%s/elm/Gen/%s.elm', config->{root}, $module;

    # The imports aren't necessary in all the files, but might as well add them.
    $contents = <<~"EOF";
        -- This file is automatically generated from lib/VNWeb/Elm.pm.
        -- Do not edit, your changes will be lost.
        module Gen.$module exposing (..)
        import Http
        import Html
        import Html.Attributes as A
        import Json.Encode as JE
        import Json.Decode as JD
        $contents
        EOF

    # Don't write anything if the file hasn't changed.
    my $oldcontents = do {
        local $/=undef; my $F;
        open($F, '<:utf8', $fn) ? <$F> : '';
    };
    return if $oldcontents eq $contents;

    open my $F, '>:utf8', $fn or die "$fn: $!";
    print $F $contents;
}





# Create type definitions and a JSON encoder for a typical form.
# Usage:
#
#   elm_form 'FormName', $TO_ELM_SCHEMA, $TO_SERVER_SCHEMA;
#
# That will create a Gen.FormName module with the following definitions:
#
#   type alias Recv = { .. }
#   type alias Send = { .. }
#   encode : Send -> JE.Value
#   valFieldName : List Html.Attribute
#
sub elm_form {
    return if !tuwf->{elmgen};
    my($name, $out, $in) = @_;

    my $data = '';
    $data .= def_type Recv => $out->analyze if $out;
    $data .= def_type Send => $in->analyze if $in;
    $data .= encoder encode => 'Send', $in->analyze if $in;
    $data .= def_validation val => $in->analyze if $in;

    write_module $name, $data;
}



# Generate the Gen.Api module with the Response type and decoder.
sub write_api {

    # Extract all { type => 'hash' } schemas and give them their own
    # definition, so that it's easy to refer to those records in other places
    # of the Elm code, similar to def_type().
    my(@union, @decode);
    my $data = '';
    my $len = max map length, keys %apis;
    for (sort keys %apis) {
        my($name, $schema) = ($_, $apis{$_});
        my $def = $name;
        my $dec = sprintf 'JD.field "%s"%s <| %s', $name,
            ' 'x($len-(length $name)),
            @$schema == 0 ? "JD.succeed $name" :
            @$schema == 1 ? "JD.map $name"     : sprintf 'JD.map%d %s', scalar @$schema, $name;
        my $tname = "Api$name";
        for my $argn (0..$#$schema) {
            my $arg = $schema->[$argn]->analyze();
            my $jd = $arg->elm_decoder(json_decode => 'JD.', level => 3);
            $dec .= " (JD.index $argn $jd)";
            if($arg->{keys}) {
                $data .= def_type $tname, $arg;
                $def .= " $tname";
            } elsif($arg->{values} && $arg->{values}{keys}) {
                $data .= def_type $tname, $arg->{values};
                $def .= " (List $tname)";
            } else {
                $def .= ' '.$arg->elm_type();
            }
        }
        push @union, $def;
        push @decode, $dec;
    }
    $data .= sprintf "\ntype Response\n  = HTTPError Http.Error\n  | %s\n", join "\n  | ", @union;
    $data .= sprintf "\ndecode : JD.Decoder Response\ndecode = JD.oneOf\n  [ %s\n  ]", join "\n  , ", @decode;

    write_module Api => $data;
};


sub write_types {
    my $data = '';

    $data .= def urlStatic  => String => string config->{url_static};
    $data .= def adminEMail => String => string config->{admin_email};
    $data .= def userPerms  => 'List (Int, String)' => list map tuple(VNWeb::Auth::listPerms->{$_}, string $_), sort keys VNWeb::Auth::listPerms->%*;
    $data .= def skins      => 'List (String, String)' =>
                list map tuple(string $_, string tuwf->{skins}{$_}[0]),
                sort { tuwf->{skins}{$a}[0] cmp tuwf->{skins}{$b}[0] } keys tuwf->{skins}->%*;

    write_module Types => $data;
}


if(tuwf->{elmgen}) {
    mkdir config->{root}.'/elm/Gen';
    write_api;
    write_types;
    open my $F, '>', config->{root}.'/elm/Gen/.generated';
    print $F scalar gmtime;
}


1;
