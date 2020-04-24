
package VNDB::Util::CommonHTML;

use strict;
use warnings;
use TUWF ':html', 'xml_escape', 'html_escape';
use Exporter 'import';
use Algorithm::Diff::XS 'compact_diff';
use Encode 'encode_utf8', 'decode_utf8';
use VNDB::Func;
use POSIX 'ceil';

our @EXPORT = qw|
  htmlMainTabs htmlDenied htmlHiddenMessage htmlRevision
  htmlEditMessage htmlItemMessage htmlSearchBox
|;


# generates the "main tabs". These are the commonly used tabs for
# 'objects', i.e. VN/producer/release entries and users
# Arguments: u/v/r/p/g/i/c/d, object, currently selected item (empty=main)
sub htmlMainTabs {
  my($self, $type, $obj, $sel) = @_;
  $obj->{entry_hidden} = $obj->{hidden};
  $obj->{entry_locked} = $obj->{locked};
  VNWeb::HTML::_maintabs_({ type => $type, dbobj => $obj, tab => $sel||''});
}


# generates a full error page, including header and footer
sub htmlDenied { shift->resDenied }


# Generates message saying that the current item has been deleted,
# Arguments: [pvrc], obj
# Returns 1 if the use doesn't have access to the page, 0 otherwise
sub htmlHiddenMessage {
  my($self, $type, $obj) = @_;
  return 0 if !$obj->{hidden};
  my $board = $type =~ /[csd]/ ? 'db' : $type eq 'r' ? 'v'.$obj->{vn}[0]{vid} : $type.$obj->{id};
  # fetch edit summary (not present in $obj, requires the db*GetRev() methods)
  my $editsum = $type eq 'v' ? $self->dbVNGetRev(id => $obj->{id})->[0]{comments}
              : $type eq 'r' ? $self->dbReleaseGetRev(id => $obj->{id})->[0]{comments}
              : $type eq 'c' ? $self->dbCharGetRev(id => $obj->{id})->[0]{comments}
                             : $self->dbProducerGetRev(id => $obj->{id})->[0]{comments};
  div class => 'mainbox';
   h1 $obj->{title}||$obj->{name};
   div class => 'warning';
    h2 'Item deleted';
    p;
     lit 'This item has been deleted from the database. File a request on the <a href="/t/'.$board.'">discussion board</a> to undelete this page.';
     br; br;
     lit bb2html $editsum;
    end;
   end;
  end 'div';
  return $self->htmlFooter() || 1 if !$self->authCan('dbmod');
  return 0;
}


# Shows a revision, including diff if there is a previous revision.
# Arguments: v|p|r|c|d, old revision, new revision, @fields
# Where @fields is a list of fields as arrayrefs with:
#  [ shortname, displayname, %options ],
#  Where %options:
#   diff      => 1/0/regex, whether to show a diff on this field, and what to split it with (1 = character-level diff)
#   short_diff=> 1/0, when set, cut off long context in diffs
#   serialize => coderef, should convert the field into a readable string, no HTML allowed
#   htmlize   => same as serialize, but HTML is allowed and this can't be diff'ed
#   split     => coderef, should return an array of HTML strings that can be diff'ed. (implies diff => 1)
#   join      => used in combination with split, specifies the string used for joining the HTML strings
sub htmlRevision {
  my($self, $type, $old, $new, @fields) = @_;
  div class => 'mainbox revision';
   h1 "Revision $new->{rev}";

   # previous/next revision links
   a class => 'prev', href => sprintf('/%s%d.%d', $type, $new->{id}, $new->{rev}-1), '<- earlier revision' if $new->{rev} > 1;
   a class => 'next', href => sprintf('/%s%d.%d', $type, $new->{id}, $new->{rev}+1), 'later revision ->' if !$new->{lastrev};
   p class => 'center';
    a href => "/$type$new->{id}", "$type$new->{id}";
   end;

   # no previous revision, just show info about the revision itself
   if(!$old) {
     div class => 'rev';
      revheader($self, $type, $new);
      br;
      b 'Edit summary';
      br; br;
      lit bb2html($new->{comments})||'-';
     end;
   }

   # otherwise, compare the two revisions
   else {
     table class => 'stripe';
      thead;
       Tr;
        td; lit '&#xa0;'; end;
        td; revheader($self, $type, $old); end;
        td; revheader($self, $type, $new); end;
       end;
       Tr;
        td; lit '&#xa0;'; end;
        td colspan => 2;
         b "Edit summary of revision $new->{rev}:";
         br; br;
         lit bb2html($new->{comments})||'-';
        end;
       end;
      end;
      revdiff($type, $old, $new, @$_) for (
        [ ihid   => 'Deleted', serialize => sub { $_[0] ? 'Yes' : 'No' } ],
        [ ilock  => 'Locked',  serialize => sub { $_[0] ? 'Yes' : 'No' } ],
        @fields
      );
     end 'table';
   }
  end 'div';
}

sub revheader { # type, obj
  my($self, $type, $obj) = @_;
  b "Revision $obj->{rev}";
  txt ' (';
  a href => "/$type$obj->{id}.$obj->{rev}/edit", 'revert to';
  if($obj->{user_id} && $self->authCan('board')) {
    lit ' / ';
    a href => "/t/u$obj->{user_id}/new?title=Regarding%20$type$obj->{id}.$obj->{rev}", 'msg user';
  }
  txt ')';
  br;
  txt 'By ';
  VNWeb::HTML::user_($obj);
  txt ' on ';
  txt fmtdate $obj->{added}, 'full';
}

sub revdiff {
  my($type, $old, $new, $short, $display, %o) = @_;

  $o{serialize} ||= $o{htmlize};
  $o{diff} = 1 if $o{split};
  $o{join} ||= '';

  my $ser1 = $o{serialize} ? $o{serialize}->($old->{$short}, $old) : $old->{$short};
  my $ser2 = $o{serialize} ? $o{serialize}->($new->{$short}, $new) : $new->{$short};
  return if $ser1 eq $ser2;

  if($o{diff} && $ser1 && $ser2) {
    my $sep = ref $o{diff} ? qr/($o{diff})/ : qr//;
    my @ser1 = map encode_utf8($_), $o{split} ? $o{split}->($ser1) : map html_escape($_), split $sep, $ser1;
    my @ser2 = map encode_utf8($_), $o{split} ? $o{split}->($ser2) : map html_escape($_), split $sep, $ser2;
    return if $o{split} && $#ser1 == $#ser2 && !grep $ser1[$_] ne $ser2[$_], 0..$#ser1;

    $ser1 = $ser2 = '';
    my @d = compact_diff(\@ser1, \@ser2);
    my $lastchunk = int (($#d-2)/2);
    for my $i (0..$lastchunk) {
      # $i % 2 == 0  -> equal, otherwise it's different
      my $a = join($o{join}, @ser1[ $d[$i*2]   .. $d[$i*2+2]-1 ]);
      my $b = join($o{join}, @ser2[ $d[$i*2+1] .. $d[$i*2+3]-1 ]);
      # Reduce context if we have too much
      if($o{short_diff} && $i % 2 == 0 && length($a) > 300) {
        my $sep = '<b class="standout">&lt;...&gt;</b>';
        my $ctx = 100;
        $a = $i == 0          ? $sep.'<br>'.substr $a, -$ctx :
             $i == $lastchunk ? substr($a, 0, $ctx).'<br>'.$sep :
                                substr($a, 0, $ctx)."<br><br>$sep<br><br>".substr($a, -$ctx);
        $b = $a;
      }
      $ser1 .= ($ser1?$o{join}:'').($i % 2 ? qq|<b class="diff_del">$a</b>| : $a) if $a ne '';
      $ser2 .= ($ser2?$o{join}:'').($i % 2 ? qq|<b class="diff_add">$b</b>| : $b) if $b ne '';
    }
    $ser1 = decode_utf8($ser1);
    $ser2 = decode_utf8($ser2);
  } elsif(!$o{htmlize}) {
    $ser1 = html_escape $ser1;
    $ser2 = html_escape $ser2;
  }

  $ser1 = '[empty]' if !$ser1 && $ser1 ne '0';
  $ser2 = '[empty]' if !$ser2 && $ser2 ne '0';

  Tr;
   td $display;
   td class => 'tcval'; lit $ser1; end;
   td class => 'tcval'; lit $ser2; end;
  end;
}


# Generates a generic message to show as the header of the edit forms
# Arguments: v/r/p, obj, title, copy
sub htmlEditMessage {
    shift; VNWeb::HTML::editmsg_(@_);
}


# Generates a small message when the user can't edit the item,
# or the item is locked.
# Arguments: v/r/p/c, obj
sub htmlItemMessage {
  my($self, $type, $obj) = @_;
  # $type isn't being used at all... oh well.

  if($obj->{locked}) {
    p class => 'locked', 'Locked for editing';
  } elsif($self->authInfo->{id} && !$self->authCan('edit')) {
    p class => 'locked', 'You are not allowed to edit this page';
  }
}


sub htmlSearchBox {
  shift; VNWeb::HTML::searchbox_(@_);
}


1;
