package VNWeb::Producers::Edit;

use VNWeb::Prelude;


my $FORM = {
    id         => { required => 0, id => 1 },
    ptype      => { enum => \%PRODUCER_TYPE },
    name       => { maxlength => 200 },
    original   => { required => 0, default => '', maxlength => 200 },
    alias      => { required => 0, default => '', maxlength => 500 },
    lang       => { enum => \%LANGUAGE },
    website    => { required => 0, default => '', weburl => 1 },
    l_wikidata => { required => 0, uint => 1, max => (1<<31)-1 },
    desc       => { required => 0, default => '', maxlength => 5000 },
    relations  => { sort_keys => 'pid', aoh => {
        pid      => { id => 1 },
        relation => { enum => \%PRODUCER_RELATION },
        name     => { _when => 'out' },
        original => { _when => 'out', required => 0, default => '' },
    } },
    hidden     => { anybool => 1 },
    locked     => { anybool => 1 },

    authmod    => { _when => 'out', anybool => 1 },
    editsum    => { _when => 'in out', editsum => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;
my $FORM_CMP = form_compile cmp => $FORM;


TUWF::get qr{/$RE{prev}/edit} => sub {
    my $e = db_entry p => tuwf->capture('id'), tuwf->capture('rev') or return tuwf->resNotFound;
    return tuwf->resDenied if !can_edit p => $e;

    $e->{authmod} = auth->permDbmod;
    $e->{editsum} = $e->{chrev} == $e->{maxrev} ? '' : "Reverted to revision p$e->{id}.$e->{chrev}";
    $e->{ptype} = delete $e->{type};

    enrich_merge pid => 'SELECT id AS pid, name, original FROM producers WHERE id IN', $e->{relations};

    framework_ title => "Edit $e->{name}", type => 'p', dbobj => $e, tab => 'edit',
    sub {
        editmsg_ p => $e, "Edit $e->{name}";
        elm_ ProducerEdit => $FORM_OUT, $e;
    };
};


TUWF::get qr{/p/add}, sub {
    return tuwf->resDenied if !can_edit p => undef;

    framework_ title => 'Add producer',
    sub {
        editmsg_ p => undef, 'Add producer';
        elm_ ProducerEdit => $FORM_OUT, { elm_empty($FORM_OUT)->%*, lang => 'ja' };
    };
};


elm_api ProducerEdit => $FORM_OUT, $FORM_IN, sub {
    my $data = shift;
    my $new = !$data->{id};
    my $e = $new ? { id => 0 } : db_entry p => $data->{id} or return tuwf->resNotFound;
    return elm_Unauth if !can_edit p => $e;

    if(!auth->permDbmod) {
        $data->{hidden} = $e->{hidden}||0;
        $data->{locked} = $e->{locked}||0;
    }
    $data->{desc} = bb_subst_links $data->{desc};
    $data->{alias} =~ s/\n\n+/\n/;

    $data->{relations} = [] if $data->{hidden};
    validate_dbid 'SELECT id FROM producers WHERE id IN', map $_->{pid}, $data->{relations}->@*;
    die "Relation with self" if grep $_->{pid} == $e->{id}, $data->{relations}->@*;

    $e->{ptype} = $e->{type};
    $data->{type} = $data->{ptype};
    return elm_Unchanged if !$new && !form_changed $FORM_CMP, $data, $e;
    my($id,undef,$rev) = db_edit p => $e->{id}, $data;
    update_reverse($id, $rev, $e, $data);
    elm_Redirect "/p$id.$rev";
};


sub update_reverse {
    my($id, $rev, $old, $new) = @_;

    my %old = map +($_->{pid}, $_), $old->{relations} ? $old->{relations}->@* : ();
    my %new = map +($_->{pid}, $_), $new->{relations}->@*;

    # Updates to be performed, pid => { pid => x, relation => y } or undef if the relation should be removed.
    my %upd;

    for my $i (keys %old, keys %new) {
        if($old{$i} && !$new{$i}) {
            $upd{$i} = undef;
        } elsif(!$old{$i} || $old{$i}{relation} ne $new{$i}{relation}) {
            $upd{$i} = {
                pid      => $id,
                relation => $PRODUCER_RELATION{ $new{$i}{relation} }{reverse},
            };
        }
    }

    for my $i (keys %upd) {
        my $e = db_entry p => $i;
        $e->{relations} = [
            $upd{$i} ? $upd{$i} : (),
            grep $_->{pid} != $id, $e->{relations}->@*
        ];
        $e->{editsum} = "Reverse relation update caused by revision p$id.$rev";
        db_edit p => $i, $e, 1;
    }
}

1;
