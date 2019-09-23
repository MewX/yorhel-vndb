package VNWeb::Docs::Page;

use VNWeb::Prelude;
use VNWeb::Docs::Lib;


sub _index_ {
    ul_ class => 'index', sub {
        li_ sub { b_ 'Guidelines' };
        li_ sub { a_ href => '/d5',  'Editing Guidelines' };
        li_ sub { a_ href => '/d2',  'Visual Novels' };
        li_ sub { a_ href => '/d15', 'Special Games' };
        li_ sub { a_ href => '/d3',  'Releases' };
        li_ sub { a_ href => '/d4',  'Producers' };
        li_ sub { a_ href => '/d16', 'Staff' };
        li_ sub { a_ href => '/d12', 'Characters' };
        li_ sub { a_ href => '/d10', 'Tags & Traits' };
        li_ sub { a_ href => '/d13', 'Capturing Screenshots' };
        li_ sub { b_ 'About VNDB' };
        li_ sub { a_ href => '/d9',  'Discussion Board' };
        li_ sub { a_ href => '/d6',  'FAQ' };
        li_ sub { a_ href => '/d7',  'About Us' };
        li_ sub { a_ href => '/d17', 'Privacy Policy & Licensing' };
        li_ sub { a_ href => '/d11', 'Database API' };
        li_ sub { a_ href => '/d14', 'Database Dumps' };
        li_ sub { a_ href => '/d18', 'Database Querying' };
        li_ sub { a_ href => '/d8',  'Development' };
    }
}


sub _rev_ {
    my $d = shift;
    revision_ d => $d, sub {},
        [ title   => 'Title'    ],
        [ content => 'Contents' ];
}


# A little in-memory cache of the rendered HTML for the latest revision of each
# doc page. md2html() performance is "acceptable" for regular page loads but
# can still feel a little sluggish.
my %cache; # chid => html


TUWF::get qr{/$RE{drev}} => sub {
    my $d = db_entry d => tuwf->capture('id'), tuwf->capture('rev');
    return tuwf->resNotFound if !$d;

    my $html = $cache{$d->{chid}} || md2html $d->{content};
    $cache{$d->{chid}} ||= $html if $d->{chrev} == $d->{maxrev};

    framework_ title => $d->{title}, type => 'd', dbobj => $d, hiddenmsg => 1,
    sub {
        _rev_ $d if tuwf->capture('rev');
        div_ class => 'mainbox', sub {
            h1_ $d->{title};
            div_ class => 'docs', sub {
                _index_;
                lit_ $html;
                clearfloat_;
            };
        };
    };
};

1;
