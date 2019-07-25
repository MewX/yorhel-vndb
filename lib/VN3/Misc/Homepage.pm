package VN3::User::Login;

use VN3::Prelude;


TUWF::get '/' => sub {
    Framework title => 'VNDB', sub {
        H1 'Hello, World!';
        P sub {
            Txt 'This is the place where version 3 of ';
            A href => 'https://vndb.org/', 'VNDB.org';
            Txt ' is being developed. Some random notes:';
            Ul sub {
                Li 'This test site interfaces directly with the same database as the main site, which makes it easier to test all the functionality and find odd test cases.';
                Li 'This test site is very incomplete, don\'t be surprised to see 404\'s or other things that don\'t work.';
                Li 'This is a long-term project, don\'t expect this new design to replace the main site anytime soon.';
                Li sub {
                    Txt 'Feedback/comments/ideas or want to help out? Post in ';
                    A href => 'https://code.blicky.net/yorhel/vndb/issues/2', 'this issue';
                    Txt ' or create a new one.';
                };
                Li sub {
                    Txt 'You can follow development activity on the ';
                    A href => 'https://code.blicky.net/yorhel/vndb/src/branch/v3', 'git repo.';
                };
            };
        };
    };
};

1;
