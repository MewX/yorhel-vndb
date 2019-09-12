package VN3::Producer::Edit;

use VN3::Prelude;


my $FORM = {
    alias       => { required => 0, default => '', maxlength => 500 },
    desc        => { required => 0, default => '', maxlength => 5000 },
    hidden      => { anybool => 1 },
    l_wp        => { required => 0, default => '', maxlength => 150 },
    lang        => { language => 1 },
    locked      => { anybool => 1 },
    original    => { required => 0, default => '', maxlength => 200 },
    name        => { maxlength => 200 },
    ptype       => { enum => \%PRODUCER_TYPE }, # This is 'type' in the database, but renamed for Elm compat
    relations   => { maxlength => 50, sort_keys => 'pid', aoh => {
        pid       => { id => 1 }, # X
        relation  => { producer_relation => 1 },
        name      => { _when => 'out' },
    } },
    website     => { required => 0, default => '', weburl => 1 },

    id          => { _when => 'out', required => 0, id => 1 },
    authmod     => { _when => 'out', anybool => 1 },
    editsum     => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

elm_form ProdEdit => $FORM_OUT, $FORM_IN;


TUWF::get qr{/$PREV_RE/edit} => sub {
    my $p = entry p => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit p => $p;

    enrich pid => q{SELECT id AS pid, name FROM producers WHERE id IN} => $p->{relations};

    $p->{l_wp} //= ''; # TODO: The DB currently uses NULL when no wp link is provided, this should be an empty string instead to be consistent with most other fields.
    $p->{ptype} = delete $p->{type};
    $p->{authmod} = auth->permDbmod;
    $p->{editsum} = $p->{chrev} == $p->{maxrev} ? '' : "Reverted to revision p$p->{id}.$p->{chrev}";

    Framework index => 0, title => "Edit $p->{name}",
    top => sub {
        Div class => 'col-md', sub {
            EntryEdit p => $p;
            Div class => 'detail-page-title', sub {
                Txt $p->{name};
                Debug $p;
            };
        };
    }, sub {
        FullPageForm module => 'ProdEdit.Main', data => $p, schema => $FORM_OUT, sections => [
            general     => 'General info',
            relations   => 'Relations',
        ];
    };
};


TUWF::get '/p/add', sub {
    return tuwf->resDenied if !auth->permEdit;
    Framework index => 0, title => 'Add a new producer', narrow => 1, sub {
        Div class => 'row', sub {
            Div class => 'col-md col-md--1', sub { Div 'data-elm-module' => 'ProdEdit.New', '' };
        };
    };
};


json_api qr{/(?:$PID_RE/edit|p/add)}, $FORM_IN, sub {
    my $data = shift;
    my $new = !tuwf->capture('id');
    my $p = $new ? { id => 0 } : entry p => tuwf->capture('id') or return tuwf->resNotFound;

    return $elm_Unauth->() if !can_edit p => $p;

    $data->{l_wp} ||= undef;
    if(!auth->permDbmod) {
        $data->{hidden} = $p->{hidden}||0;
        $data->{locked} = $p->{locked}||0;
    }
    $data->{relations} = [] if $data->{hidden};

    die "Relation with self" if grep $_->{pid} == $p->{id}, @{$data->{relations}};
    validate_dbid 'SELECT id FROM producers WHERE id IN', map $_->{pid}, @{$data->{relations}};

    $data->{desc} = bb_subst_links $data->{desc};

    $p->{ptype} = delete $p->{type};
    return $elm_Unchanged->() if !$new && !form_changed $FORM_CMP, $data, $p;
    $data->{type} = delete $data->{ptype};

    my($id,undef,$rev) = update_entry p => $p->{id}, $data;

    update_reverse($id, $rev, $p, $data);

    $elm_Changed->($id, $rev);
};


sub update_reverse {
    my($id, $rev, $old, $new) = @_;

    my %old = map +($_->{pid}, $_), $old->{relations} ? @{$old->{relations}} : ();
    my %new = map +($_->{pid}, $_), @{$new->{relations}};

    # Updates to be performed, pid => { pid => x, relation => y } or undef if the relation should be removed.
    my %upd;

    for my $i (keys %old, keys %new) {
        if($old{$i} && !$new{$i}) {
            $upd{$i} = undef;
        } elsif(!$old{$i} || $old{$i}{relation} ne $new{$i}{relation}) {
            $upd{$i} = {
                pid => $id,
                relation => producer_relation_reverse($new{$i}{relation}),
            };
        }
    }

    for my $i (keys %upd) {
        my $p = entry p => $i;
        $p->{relations} = [
            $upd{$i} ? $upd{$i} : (),
            grep $_->{pid} != $id, @{$p->{relations}}
        ];
        $p->{editsum} = "Reverse relation update caused by revision p$id.$rev";
        update_entry p => $i, $p, 1;
    }
}

1;
