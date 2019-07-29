package VN3::Staff::Edit;

use VN3::Prelude;


my $FORM = {
    aid         => { int => 1, range => [ -1000, 1<<40 ] }, # X
    alias       => { maxlength => 100, sort_keys => 'aid', aoh => {
        aid       => { int => 1, range => [ -1000, 1<<40 ] }, # X, negative IDs are for new aliases
        name      => { maxlength => 200 },
        original  => { maxlength => 200, required => 0, default => '' },
        inuse     => { anybool => 1, _when => 'out' },
    } },
    desc        => { required => 0, default => '', maxlength => 5000 },
    gender      => { gender => 1 },
    hidden      => { anybool => 1 },
    l_site      => { required => 0, default => '', weburl => 1 },
    l_wp        => { required => 0, default => '', maxlength => 150 },
    l_twitter   => { required => 0, default => '', maxlength => 150 },
    l_anidb     => { required => 0, id => 1 },
    lang        => { language => 1 },
    locked      => { anybool => 1 },

    id          => { _when => 'out', required => 0, id => 1 },
    authmod     => { _when => 'out', anybool => 1 },
    editsum     => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;

elm_form StaffEdit => $FORM_OUT, $FORM_IN;


TUWF::get qr{/$SREV_RE/edit} => sub {
    my $e = entry s => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit s => $e;

    $e->{authmod} = auth->permDbmod;
    $e->{editsum} = $e->{chrev} == $e->{maxrev} ? '' : "Reverted to revision s$e->{id}.$e->{chrev}";

    enrich aid => sub { sql '
        SELECT aid, EXISTS(SELECT 1 FROM vn_staff WHERE aid = x.aid UNION ALL SELECT 1 FROM vn_seiyuu WHERE aid = x.aid) AS inuse
        FROM unnest(', sql_array(@{$_[0]}), '::int[]) AS x(aid)'
    }, $e->{alias};

    my $name = (grep $_->{aid} == $e->{aid}, @{$e->{alias}})[0]{name};
    Framework index => 0, narrow => 1, title => "Edit $name",
    top => sub {
        Div class => 'col-md', sub {
            EntryEdit s => $e;
            Div class => 'detail-page-title', sub {
                Txt $name,
                Debug $e;
            };
        };
    }, sub {
        FullPageForm module => 'StaffEdit.Main', data => $e, schema => $FORM_OUT;
    };
};


TUWF::get '/s/new', sub {
    return tuwf->resDenied if !auth->permEdit;
    Framework index => 0, title => 'Add a new staff entry', narrow => 1, sub {
        Div class => 'row', sub {
            Div class => 'col-md col-md--1', sub { Div 'data-elm-module' => 'StaffEdit.New', '' };
        };
    };
};


json_api qr{/(?:$SID_RE/edit|s/add)}, $FORM_IN, sub {
    my $data = shift;
    my $new = !tuwf->capture('id');
    my $e = $new ? { id => 0 } : entry s => tuwf->capture('id') or return tuwf->resNotFound;

    return $elm_Unauth->() if !can_edit s => $e;

    if(!auth->permDbmod) {
        $data->{hidden} = $e->{hidden}||0;
        $data->{locked} = $e->{locked}||0;
    }

    # For positive alias IDs: Make sure they exist and are owned by this entry.
    validate_dbid
        sub { sql 'SELECT aid FROM staff_alias WHERE id =', \$e->{id}, ' AND aid IN', $_[0] },
        grep $_>=0, map $_->{aid}, @{$data->{alias}};

    # For negative alias IDs: Assign a new ID.
    for my $alias (@{$data->{alias}}) {
        if($alias->{aid} < 0) {
            my $new = tuwf->dbVali(select => sql_func nextval => \'staff_alias_aid_seq');
            $data->{aid} = $new if $alias->{aid} == $data->{aid};
            $alias->{aid} = $new;
        }
    }
    # We rely on Postgres to throw an error if we attempt to delete an alias that is still being referenced.

    $data->{desc} = bb_subst_links $data->{desc};

    return $elm_Unchanged->() if !$new && !form_changed $FORM_CMP, $data, $e;
    my($id,undef,$rev) = update_entry s => $e->{id}, $data;
    $elm_Changed->($id, $rev);
};

1;
