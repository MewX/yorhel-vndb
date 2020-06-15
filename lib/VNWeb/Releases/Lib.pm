package VNWeb::Releases::Lib;

use VNWeb::Prelude;
use Exporter 'import';

our @EXPORT = qw/enrich_release release_row_/;


# Enrich a list of releases so that it's suitable for release_row_().
# Assumption: Each release already has id, type, patch, released, gtin and enrich_extlinks().
sub enrich_release {
    my($r) = @_;
    enrich_merge id => 'SELECT id, title, original, notes, minage, freeware, doujin, reso_x, reso_y, voiced, ani_story, ani_ero, uncensored FROM releases WHERE id IN', $r;
    enrich_merge id => sql('SELECT rid as id, status as rlist_status FROM rlists WHERE uid =', \auth->uid, 'AND rid IN'), $r if auth;
    enrich_flatten lang => id => id => sub { sql 'SELECT id, lang FROM releases_lang WHERE id IN', $_, 'ORDER BY id, lang' }, $r;
    enrich_flatten platforms => id => id => sub { sql 'SELECT id, platform FROM releases_platforms WHERE id IN', $_, 'ORDER BY id, platform' }, $r;
    enrich media => id => id => sub { 'SELECT id, medium, qty FROM releases_media WHERE id IN', $_, 'ORDER BY id, medium' }, $r;
}


sub release_extlinks_ {
    my($r, $id) = @_;
    return if !$r->{extlinks}->@*;

    if($r->{extlinks}->@* == 1 && $r->{website}) {
        a_ href => $r->{website}, sub {
            abbr_ class => 'icons external', title => 'Official website', '';
        };
        return
    }

    div_ class => 'elm_dd_noarrow elm_dd_hover elm_dd_left elm_dd_relextlink', sub {
        div_ class => 'elm_dd', sub {
            a_ href => $r->{website}||'#', sub {
                txt_ scalar $r->{extlinks}->@*;
                abbr_ class => 'icons external', title => 'External link', '';
            };
            div_ sub {
                ul_ sub {
                    li_ sub {
                        a_ href => $_->[1], sub {
                            span_ $_->[2] if length $_->[2];
                            txt_ $_->[0];
                        }
                    } for $r->{extlinks}->@*;
                }
            }
        }
    }
}


sub release_row_ {
    my($r, $id, $prodpage) = @_;

    my sub icon_ {
        my($img, $label, $class) = @_;
        $class = $class ? " release_icon_$class" : '';
        img_ src => config->{url_static}."/f/$img.svg", class => "release_icons$class", title => $label;
    }

    my sub icons_ {
        my($r) = @_;
        icon_ 'voiced', $VOICED{$r->{voiced}}{txt}, "voiced$r->{voiced}" if $r->{voiced};
        icon_ 'story_animated', "Story: $ANIMATED{$r->{ani_story}}{txt}", "anim$r->{ani_story}" if $r->{ani_story};
        icon_ 'ero_animated', "Ero: $ANIMATED{$r->{ani_ero}}{txt}", "anim$r->{ani_ero}" if $r->{ani_ero};
        icon_ 'free', 'Freeware' if $r->{freeware};
        icon_ 'nonfree', 'Non-free' if !$r->{freeware};
        icon_ 'doujin', 'Doujin' if !$r->{patch} && $r->{doujin};
        icon_ 'commercial', 'Commercial' if !$r->{patch} && !$r->{doujin};
        if($r->{reso_y}) {
            my $type = $r->{reso_y} == 1 ? 'custom' : $r->{reso_x} / $r->{reso_y} > 4/3 ? '16-9' : '4-3';
            # Ugly workaround: PC-98 has non-square pixels, thus not widescreen
            $type = '4-3' if $type eq '16-9' && grep $_ eq 'p98', $r->{platforms}->@*;
            icon_ "resolution_$type", resolution $r;
        }
        icon_ $MEDIUM{ $r->{media}[0]{medium} }{icon}, join ', ', map fmtmedia($_->{medium}, $_->{qty}), $r->{media}->@* if $r->{media}->@*;
        icon_ 'uncensor', 'Uncensored' if $r->{uncensored};
        icon_ 'notes', bb2text $r->{notes} if $r->{notes};
    }

    tr_ sub {
        td_ class => 'tc1', sub { rdate_ $r->{released} };
        td_ class => 'tc2', $r->{minage} < 0 ? '' : minage $r->{minage};
        td_ class => 'tc3', sub {
            abbr_ class => "icons $_", title => $PLATFORM{$_}, '' for grep $_ ne 'oth', $r->{platforms}->@*;
            if($prodpage) {
                abbr_ class => "icons lang $_", title => $LANGUAGE{$_}, '' for $r->{lang}->@*;
            }
            abbr_ class => "icons rt$r->{type}", title => $r->{type}, '';
        };
        td_ class => 'tc4', sub {
            a_ href => "/r$r->{id}", title => $r->{original}||$r->{title}, $r->{title};
            b_ class => 'grayedout', ' (patch)' if $r->{patch};
        };
        td_ class => 'tc_icons', sub { icons_ $r };
        td_ class => 'tc_prod', join ' & ', $r->{publisher} ? 'Pub' : (), $r->{developer} ? 'Dev' : () if $prodpage;
        td_ class => 'tc5 elm_dd_left', sub {
            elm_ 'UList.ReleaseEdit', $VNWeb::User::Lists::RLIST_STATUS, { rid => $r->{id}, uid => auth->uid, status => $r->{rlist_status}, empty => '--' } if auth;
        };
        td_ class => 'tc6', sub { release_extlinks_ $r, "${id}_$r->{id}" };
    }
}

1;
