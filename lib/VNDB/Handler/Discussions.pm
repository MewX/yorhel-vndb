
package VNDB::Handler::Discussions;

use strict;
use warnings;
use TUWF ':html', 'xml_escape';
use POSIX 'ceil';
use VNDB::Func;
use VNDB::Types;


TUWF::register(
  qr{t([1-9]\d*)/reply}              => \&edit,
  qr{t([1-9]\d*)\.([1-9]\d*)/edit}   => \&edit,
  qr{t/(db|an|ge|[vpu])([1-9]\d*)?/new} => \&edit,
);


sub caneditpost {
  my($self, $post) = @_;
  return $self->authCan('boardmod') ||
    ($self->authInfo->{id} && $post->{user_id} == $self->authInfo->{id} && !$post->{hidden} && time()-$post->{date} < $self->{board_edit_time})
}


# Arguments, action
#  tid          reply
#  tid, 1       edit thread
#  tid, num     edit post
#  type, (iid)  start new thread
sub edit {
  my($self, $tid, $num) = @_;
  $num ||= 0;

  # in case we start a new thread, parse boards
  my $board = '';
  if($tid !~ /^\d+$/) {
    return $self->resNotFound if $tid =~ /(db|an|ge)/ && $num || $tid =~ /[vpu]/ && !$num;
    $board = $tid.($num||'');
    $tid = 0;
    $num = 0;
  }

  # get thread and post, if any
  my $t = $tid && $self->dbThreadGet(id => $tid, what => 'boards poll')->[0];
  return $self->resNotFound if $tid && !$t->{id};

  my $p = $num && $self->dbPostGet(tid => $tid, num => $num, what => 'user')->[0];
  return $self->resNotFound if $num && !$p->{num};

  # are we allowed to perform this action?
  return $self->htmlDenied if !$self->authCan('board')
    || ($tid && ($t->{locked} || $t->{hidden}) && !$self->authCan('boardmod'))
    || ($num && !caneditpost($self, $p));

  # check form etc...
  my $frm;
  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    my $haspoll = $self->reqPost('poll') && 1;
    $frm = $self->formValidate(
      !$tid || $num == 1 ? (
        { post => 'title', maxlength => 50 },
        { post => 'boards', maxlength => 200 },
        $haspoll ? (
          { post => 'poll', required => 0 },
          { post => 'poll_question', required => 1, maxlength => 100 },
          { post => 'poll_options', required => 1, maxlength => 100*$self->{poll_options} },
          { post => 'poll_max_options', required => 1, default => 1, template => 'uint', min => 1, max => $self->{poll_options} },
          { post => 'poll_preview', required => 0 },
          { post => 'poll_recast', required => 0 },
        ) : (),
      ) : (),
      $self->authCan('boardmod') ? (
        { post => 'locked', required => 0 },
        { post => 'hidden', required => 0 },
        { post => 'nolastmod', required => 0 },
      ) : (),
      $self->authCan('boardmod') || $self->authCan('dbmod') || $self->authCan('tagmod') ? (
        { post => 'private', required => 0 },
      ) : (),
      { post => 'msg', maxlength => 32768 },
      { post => 'fullreply', required => 0 },
    );

    $frm->{_err} = 1 if $frm->{fullreply};

    # check for double-posting
    push @{$frm->{_err}}, 'Please wait 30 seconds before making another post' if !$num && !$frm->{_err} && $self->dbPostGet(
      uid => $self->authInfo->{id}, tid => $tid, mindate => time - 30, results => 1, $tid ? () : (num => 1))->[0]{num};

    # Don't allow regular users to create more than 5 threads a day
    push @{$frm->{_err}}, 'You can only create 5 threads every 24 hours' if
      !$tid && !$self->authCan('boardmod') &&
      @{$self->dbPostGet(uid => $self->authInfo->{id}, mindate => time - 24*3600, num => 1)} >= 5;

    # parse and validate the boards
    my @boards;
    if(!$frm->{_err} && $frm->{boards}) {
      for (split /[ ,]/, $frm->{boards}) {
        my($ty, $id) = /^([a-z]{1,2})([0-9]*)$/ ? ($1, $2) : ($_, '');
        push @boards, [ $ty, $id ] if !grep $_->[0].$_->[1] eq $ty.$id, @boards;
        my $bt = $BOARD_TYPE{$ty};
        push @{$frm->{_err}}, "Wrong board: $_" if
             !$ty || !$bt
          || !$self->authCan($bt->{post_perm})
          || !$bt->{dbitem} && $id || $bt->{dbitem} && !$id
          || $ty eq 'v' && !$self->dbVNGet(id => $id)->[0]{id}
          || $ty eq 'p' && !$self->dbProducerGet(id => $id)->[0]{id}
          || $ty eq 'u' && !$self->dbUserGet(uid => $id)->[0]{id};
      }
    }

    # validate poll options
    my @poll_options;
    if(!$frm->{_err} && $haspoll) {
      @poll_options = split /\s*\n\s*/, $frm->{poll_options};
      push @{$frm->{_err}}, [ 'poll_options', 'mincount', 2 ] if @poll_options < 2;
      push @{$frm->{_err}}, [ 'poll_options', 'maxcount', $frm->{poll_max_options} ] if @poll_options > $self->{poll_options};
      push @{$frm->{_err}}, [ 'poll_max_options', 'template', 'uint' ] if @poll_options > 1 && @poll_options < $frm->{poll_max_options};
    }

    if(!$frm->{_err}) {
      my($ntid, $nnum) = ($tid, $num);

      # create/edit thread
      if(!$tid || $num == 1) {
        my $pollchange = $haspoll && (!$t
          || ($t->{poll_question}||'') ne $frm->{poll_question}
          ||  $t->{poll_max_options} != $frm->{poll_max_options}
          || join("\n", map $_->[1], @{$t->{poll_options}}) ne join("\n", @poll_options)
        );
        my %thread = (
          title => $frm->{title},
          boards => \@boards,
          hidden => $frm->{hidden},
          locked => $frm->{locked},
          private => $frm->{private},
          poll_preview => $frm->{poll_preview}||0,
          poll_recast  => $frm->{poll_recast}||0,
          !$haspoll ? (
            poll_question => undef  # Make sure any existing poll gets deleted
          ) : $pollchange ? (
            poll_question    => $frm->{poll_question},
            poll_max_options => $frm->{poll_max_options},
            poll_options     => \@poll_options
          ) : (),
        );
        $self->dbThreadEdit($tid, %thread)  if $tid;
        $ntid = $self->dbThreadAdd(%thread) if !$tid;
      }

      # create/edit post
      my %post = (
        msg => $self->bbSubstLinks($frm->{msg}),
        hidden => $num != 1 && $frm->{hidden},
        lastmod => !$num || $frm->{nolastmod} ? 0 : time,
      );
      $self->dbPostEdit($tid, $num, %post)   if $num;
      $nnum = $self->dbPostAdd($ntid, %post) if !$num;

      return $self->resRedirect("/t$ntid".($nnum > 25 ? '/'.ceil($nnum/25) : '').'#'.$nnum, 'post');
    }
  }

  # fill out form if we have some data
  if($p) {
    $frm->{msg} ||= $p->{msg};
    $frm->{hidden} = $p->{hidden} if $num != 1 && !exists $frm->{hidden};
    if($num == 1) {
      $frm->{boards} ||= join ' ', sort map $_->[1]?$_->[0].$_->[1]:$_->[0], @{$t->{boards}};
      $frm->{title} ||= $t->{title};
      $frm->{locked}  //= $t->{locked};
      $frm->{hidden}  //= $t->{hidden};
      $frm->{private} //= $t->{private};
      if($t->{haspoll}) {
        $frm->{poll}     //= 1;
        $frm->{poll_question}   ||= $t->{poll_question};
        $frm->{poll_max_options} ||= $t->{poll_max_options};
        $frm->{poll_preview} //= $t->{poll_preview};
        $frm->{poll_recast}  //= $t->{poll_recast};
        $frm->{poll_options} ||= join "\n", map $_->[1], @{$t->{poll_options}};
      }
    }
  }
  delete $frm->{_err} unless ref $frm->{_err};
  $frm->{boards} ||= $board.($board =~ /^u/ ? ' u'.$self->authInfo->{id} : '');
  $frm->{title} ||= $self->reqGet('title');
  $frm->{poll_preview} //= 1;
  $frm->{poll_max_options} ||= 1;

  # generate html
  my $url = !$tid ? "/t/$board/new" : !$num ? "/t$tid/reply" : "/t$tid.$num/edit";
  my $title = !$tid ? 'Start new thread' :
              !$num ? "Reply to $t->{title}" :
                      'Edit post';
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlForm({ frm => $frm, action => $url }, 'postedit' => [$title,
    [ static => label => 'Username', content => sub { VNWeb::HTML::user_($p || VNWeb::Auth::auth->user); '' } ],
    !$tid || $num == 1 ? (
      [ input  => short => 'title', name => 'Thread title' ],
      [ input  => short => 'boards',  name => 'Board(s)' ],
      [ static => content => 'Read <a href="/d9#2">d9#2</a> for information about how to specify boards.' ],
      $self->authCan('boardmod') ? (
        [ check => name => 'Locked', short => 'locked' ],
      ) : (),
      $self->authCan('boardmod') || $self->authCan('dbmod') || $self->authCan('tagmod') ? (
        [ check => name => 'Private (only visible to users mentioned in the boards)', short => 'private' ],
      ) : (),
    ) : (
      [ static => label => 'Topic', content => qq|<a href="/t$tid">|.xml_escape($t->{title}).'</a>' ],
    ),
    $self->authCan('boardmod') ? (
      [ check => name => 'Hidden', short => 'hidden' ],
      $num ? (
        [ check => name => 'Don\'t update last modified field', short => 'nolastmod' ],
      ) : (),
    ) : (),
    [ text   => name => 'Message<br /><b class="standout">English please!</b>', short => 'msg', rows => 25, cols => 75 ],
    [ static => content => 'See <a href="/d9#3">d9#3</a> for the allowed formatting codes' ],
    (!$tid || $num == 1) ? (
      [ static => content => '<br />' ],
      [ check => short => 'poll', name => 'Add poll' ],
      $num && $frm->{poll_question} ? (
        [ static => content => '<b class="standout">All votes will be reset if any changes to the poll fields are made!</b>' ]
      ) : (),
      [ input => short => 'poll_question', name => 'Poll question', width => 250 ],
      [ text  => short => 'poll_options', name => "Poll options<br /><i>one per line,<br />$self->{poll_options} max</i>", rows => 8, cols => 35 ],
      [ input => short => 'poll_max_options',width => 16, post => ' Number of options voter is allowed to choose' ],
      [ hidden => short => 'poll_preview' ],
      [ hidden => short => 'poll_recast' ],
    ) : (),
  ]);
  $self->htmlFooter;
}


1;

