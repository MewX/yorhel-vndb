package VN3::User::Settings;

use VN3::Prelude;
use VN3::ElmGen;


my $FORM = {
    username  => { username => 1 },
    mail      => { email => 1 },
    perm      => { uint => 1, func => sub { ($_[0] & ~auth->allPerms) == 0 } },
    ign_votes => { anybool => 1 },
    hide_list => { anybool => 1 },
    show_nsfw => { anybool => 1 },
    traits_sexual => { anybool => 1 },
    tags_all  => { anybool => 1 },
    tags_cont => { anybool => 1 },
    tags_ero  => { anybool => 1 },
    tags_tech => { anybool => 1 },
    spoilers  => { uint => 1, range => [ 0, 2 ] },

    password  => { _when => 'in', required => 0, type => 'hash', keys => {
        old   => { password => 1 },
        new   => { password => 1 }
    } },

    id        => { _when => 'out', uint => 1 },
    authmod   => { _when => 'out', anybool => 1 },
};

my $FORM_OUT = form_compile out => $FORM;
my $FORM_IN  = form_compile in  => $FORM;

elm_form UserEdit => $FORM_OUT, $FORM_IN;


TUWF::get qr{/$UID_RE/edit}, sub {
    my $u = tuwf->dbRowi('SELECT id, username, perm, ign_votes FROM users WHERE id =', \tuwf->capture('id'));

    return tuwf->resNotFound if !can_edit u => $u;

    $u->{mail} = tuwf->dbVali(select => sql_func user_getmail => \$u->{id}, \auth->uid, sql_fromhex auth->token);
    $u->{authmod} = auth->permUsermod;

    # Let's not disclose this (though it's not hard to find out through other means)
    if(!auth->permUsermod) {
        $u->{ign_votes} = 0;
        $u->{perm} = auth->defaultPerms;
    }

    my $prefs = { map +($_->{key}, $_->{value}), @{ tuwf->dbAlli('SELECT key, value FROM users_prefs WHERE uid =', \$u->{id}) }};
    $u->{$_} = $prefs->{$_}||'' for qw/hide_list show_nsfw traits_sexual tags_all spoilers/;
    $u->{spoilers} ||= 0;
    $u->{"tags_$_"} = (($prefs->{tags_cat}||'cont,tech') =~ /$_/) for qw/cont ero tech/;

    my $title = $u->{id} == auth->uid ? 'My Preferences' : "Edit $u->{username}";
    Framework title => $title, noindex => 1, narrow => 1, sub {
        FullPageForm module => 'User.Settings', data => $u, schema => $FORM_OUT;
    };
};


json_api qr{/$UID_RE/edit}, $FORM_IN, sub {
    my $data = shift;
    my $id = tuwf->capture('id');

    return tuwf->resJSON({Unauth => 1}) if !can_edit u => { id => $id };

    if(auth->permUsermod) {
        tuwf->dbExeci(update => users => set => {
            username  => $data->{username},
            ign_votes => $data->{ign_votes},
            email_confirmed => 1,
        }, where => { id => $id });
        tuwf->dbExeci(select => sql_func user_setperm => \$id, \auth->uid, sql_fromhex(auth->token), \$data->{perm});
    }

    if($data->{password}) {
        return tuwf->resJSON({BadPass => 1}) if tuwf->isUnsafePass($data->{password}{new});

        if(auth->uid == $id) {
            return tuwf->resJSON({BadLogin => 1}) if !auth->setpass($id, undef, $data->{password}{old}, $data->{password}{new});
        } else {
            tuwf->dbExeci(select => sql_func user_admin_setpass => \$id, \auth->uid,
                sql_fromhex(auth->token), sql_fromhex auth->_preparepass($data->{password}{new})
            );
        }
    }

    tuwf->dbExeci(select => sql_func user_setmail => \$id, \auth->uid, sql_fromhex(auth->token), \$data->{mail});

    auth->prefSet($_, $data->{$_}, $id) for qw/hide_list show_nsfw traits_sexual tags_all spoilers/;
    auth->prefSet(tags_cat => join(',', map $data->{"tags_$_"} ? $_ : (), qw/cont ero tech/), $id);

    tuwf->resJSON({Success => 1});
};

1;
