package VN3::User::Lib;

use VN3::Prelude;

our @EXPORT = qw/show_list TopNav/;


# Whether we can see the user's list
sub show_list {
    my $u = shift;
    die "Can't determine show_list() when hide_list preference is not known" if !exists $u->{hide_list};
    auth->permUsermod || !$u->{hide_list} || $u->{id} == (auth->uid||0);
}


sub TopNav {
    my($page, $u) = @_;

    Div class => 'nav raised-top-nav', sub {
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'details'),    sub { A href => "/u$u->{id}",       class => 'nav__link', 'Details'; };
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'list'),       sub { A href => "/u$u->{id}/list",  class => 'nav__link', 'List'; } if show_list $u;
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'wish'),       sub { A href => "/u$u->{id}/wish",  class => 'nav__link', 'Wishlist'; } if show_list $u;
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'posts'),      sub { A href => "/u$u->{id}/posts", class => 'nav__link', 'Posts'; };
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'discussions'),sub { A href => "/t/u$u->{id}",     class => 'nav__link', 'Discussions'; };
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'tags'),       sub { A href => "/g/links?uid=$u->{id}", class => 'nav__link', 'Tags'; };
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'hist'),       sub { A href => "/u$u->{id}/hist",  class => 'nav__link', 'Contributions'; };
    };
}

1;

