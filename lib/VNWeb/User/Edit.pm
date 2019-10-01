package VNWeb::User::Edit;

use VNWeb::Prelude;

# Some validations in this form are also used by Login.elm, PassReset.elm, PassSet.elm and Register.elm
elm_form UserEdit => undef, form_compile(in => {
    email    => { email => 1 },
    password => { password => 1 },
    username => { username => 1 },
});

1;
