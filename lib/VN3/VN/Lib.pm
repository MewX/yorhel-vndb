package VN3::VN::Lib;

use VN3::Prelude;

our @EXPORT = qw/TopNav/;


sub TopNav {
    my($page, $v) = @_;

    my $rg = exists $v->{rgraph} ? $v->{rgraph} : tuwf->dbVali('SELECT rgraph FROM vn WHERE id=', \$v->{id});

    Div class => 'nav raised-top-nav', sub {
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'details'),    sub { A href => "/v$v->{id}",      class => 'nav__link', 'Details'; };
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'discussions'),sub { A href => "/t/v$v->{id}",    class => 'nav__link', 'Discussions'; }; # TODO: count
        Div mkclass('nav__item' => 1, 'nav__item--active' => $page eq 'relations'),  sub { A href => "/v$v->{id}/rg",   class => 'nav__link', 'Relations'; } if $rg;
    };
}

1;
