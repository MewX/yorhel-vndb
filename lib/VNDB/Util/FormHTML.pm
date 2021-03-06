
package VNDB::Util::FormHTML;

use strict;
use warnings;
use TUWF ':html';
use Exporter 'import';
use POSIX 'strftime';
use VNDB::Func;

our @EXPORT = qw| htmlFormError htmlFormPart htmlForm |;


# Displays friendly error message when form validation failed
# Argument is the return value of formValidate, and an optional
# argument indicating whether we should create a special mainbox
# for the errors.
sub htmlFormError {
  my($self, $frm, $mainbox) = @_;
  return if !$frm->{_err};
  if($mainbox) {
    div class => 'mainbox';
     h1 'Error';
  }
  div class => 'warning';
   h2 'Form could not be sent:';
   ul;
    for my $e (@{$frm->{_err}}) {
      if(!ref $e) {
        li $e;
        next;
      }
      if(ref $e eq 'SCALAR') {
        li; lit $$e; end;
        next;
      }
      my($field, $type, $rule) = @$e;
      ($type, $rule) = ('template', 'editsum') if $type eq 'required' && $field eq 'editsum';

      li "$field is a required field" if $type eq 'required';;
      li "$field: minimum number of values is $rule" if $type eq 'mincount';
      li "$field: maximum number of values is $rule" if $type eq 'maxcount';
      li "$field: should have at least $rule characters" if $type eq 'minlength';
      li "$field: only $rule characters allowed" if $type eq 'maxlength';
      li "$field must be one of the following: ".join(', ', @$rule) if $type eq 'enum';
      li $rule->[1] if $type eq 'func' || $type eq 'regex';
      if($type eq 'template') {
        li "$field: Invalid number" if $rule eq 'int' || $rule eq 'num' || $rule eq 'uint' || $rule eq 'page' || $rule eq 'id';
        li "$field: Invalid URL" if $rule eq 'weburl';
        li "$field: only ASCII characters allowed" if $rule eq 'ascii';
        li "Invalid email address" if $rule eq 'email';
        li "$field may only contain lowercase alphanumeric characters and a hyphen" if $rule eq 'uname';
        li 'Invalid JAN/UPC/EAN' if $rule eq 'gtin';
        li "$field: Malformed data or invalid input" if $rule eq 'json';
        li 'Invalid release date' if $rule eq 'rdate';
        li 'Invalid Wikidata ID' if $rule eq 'wikidata';
        if($rule eq 'editsum') {
          li; lit 'Please read <a href="/d5#4">the guidelines</a> on how to use the edit summary.'; end;
        }
      }
    }
   end;
  end 'div';
  end if $mainbox;
}


# Generates a form part.
# A form part is a arrayref, with the first element being the type of the part,
# and all other elements forming a hash with options specific to that type.
# Type      Options
#  hidden    short, (value)
#  json      short, (value)   # Same as hidden, but value is passed through json_encode()
#  input     short, name, (value, allow0, width, pre, post)
#  passwd    short, name
#  static    content, (label, nolabel)
#  check     name, short, (value)
#  select    name, short, options, (width, multi, size)
#  radio     name, short, options
#  text      name, short, (rows, cols)
#  date      name, short
#  part      title
sub htmlFormPart {
  my($self, $frm, $fp) = @_;
  my($type, %o) = @$fp;
  local $_ = $type;

  if(/hidden/ || /json/) {
    Tr class => 'hidden';
     td colspan => 2;
      my $val = $o{value}||$frm->{$o{short}};
      input type => 'hidden', id => $o{short}, name => $o{short}, value => /json/ ? json_encode($val||[]) : $val||'';
     end;
    end;
    return
  }

  if(/part/) {
    Tr class => 'newpart';
     td colspan => 2, $o{title};
    end;
    return;
  }

  if(/check/) {
    Tr class => 'newfield';
     td class => 'label';
      lit '&#xa0;';
     end;
     td class => 'field';
      input type => 'checkbox', name => $o{short}, id => $o{short}, tabindex => 10,
        value => $o{value}||1, ($frm->{$o{short}}||0) eq ($o{value}||1) ? ( checked => 'checked' ) : ();
      label for => $o{short};
       lit $o{name};
      end;
     end;
    end;
    return;
  }

  Tr $o{name}||$o{label} ? (class => 'newfield') : ();
   if(!$o{nolabel}) {
     td class => 'label';
      if($o{short} && $o{name}) {
        label for => $o{short};
         lit $o{name};
        end;
      } elsif($o{label}) {
        txt $o{label};
      } else {
        lit '&#xa0;';
      }
     end;
   }
   td class => 'field', $o{nolabel} ? (colspan => 2) : ();
    if(/input/) {
      lit $o{pre} if $o{pre};
      input type => 'text', class => 'text', name => $o{short}, id => $o{short}, tabindex => 10,
        value => $o{value} // ($o{allow0} ? $frm->{$o{short}}//'' : $frm->{$o{short}}||''), $o{width} ? (style => "width: $o{width}px") : ();
      lit $o{post} if $o{post};
    }
    if(/passwd/) {
      input type => 'password', class => 'text', name => $o{short}, id => $o{short}, tabindex => 10,
        value => $frm->{$o{short}}||'';
    }
    if(/static/) {
      lit ref $o{content} eq 'CODE' ? $o{content}->($self, \%o) : $o{content};
    }
    if(/select/) {
      my $l='';
      Select name => $o{short}, id => $o{short}, tabindex => 10,
        $o{width} ? (style => "width: $o{width}px") : (), $o{multi} ? (multiple => 'multiple', size => $o{size}||5) : ();
       for my $p (@{$o{options}}) {
         if($p->[2] && $l ne $p->[2]) {
           end if $l;
           $l = $p->[2];
           optgroup label => $l;
         }
         my $sel = defined $frm->{$o{short}} && ($frm->{$o{short}} eq $p->[0] || ref($frm->{$o{short}}) eq 'ARRAY' && grep $_ eq $p->[0], @{$frm->{$o{short}}});
         option value => $p->[0], $sel ? (selected => 'selected') : (), $p->[1];
       }
       end if $l;
      end;
    }
    if(/radio/) {
      for my $p (@{$o{options}}) {
        input type => 'radio', id => "$o{short}_$p->[0]", name => $o{short}, value => $p->[0], tabindex => 10,
          defined $frm->{$o{short}} && $frm->{$o{short}} eq $p->[0] ? (checked => 'checked') : ();
        label for => "$o{short}_$p->[0]", $p->[1];
      }
    }
    if(/date/) {
      input type => 'hidden', id => $o{short}, name => $o{short}, value => $frm->{$o{short}}||'', class => 'dateinput';
    }
    if(/text/) {
      textarea name => $o{short}, id => $o{short}, rows => $o{rows}||5, cols => $o{cols}||60, tabindex => 10, $frm->{$o{short}}||'';
    }
   end;
  end 'tr';
}


# Generates a form, first argument is a hashref with global options, keys:
#   frm       => the $frm as returned by formValidate,
#   action    => The location the form should POST to (also used as form id)
#   method    => post/get
#   upload    => 1/0, adds an enctype.
#   nosubmit  => 1/0, hides the submit button
#   editsum   => 1/0, adds an edit summary field before the submit button
#   continue  => 2/1/0, replace submit button with continue buttons
#   preview   => 1/0, add preview button
#   noformcode=> 1/0, remove the formcode field
# The other arguments are a list of subforms in the form
# of (subform-name => [form parts]). Each subform is shown as a
# (JavaScript-powered) tab, and has it's own 'mainbox'. This function
# automatically calls htmlFormError and adds a 'formcode' field.
sub htmlForm {
  my($self, $options, @subs) = @_;
  form action => '/nospam?'.$options->{action}, method => $options->{method}||'post', 'accept-charset' => 'utf-8',
    $options->{upload} ? (enctype => 'multipart/form-data') : ();

  if(!$options->{noformcode}) {
    div class => 'hidden';
     input type => 'hidden', name => 'formcode', value => $self->authGetCode($options->{action});
    end;
  }

  $self->htmlFormError($options->{frm}, 1);

  # tabs
  if(@subs > 2) {
    div class => 'maintabs left';
     ul id => 'jt_select';
      for (0..$#subs/2) {
        li class => 'left';
         a href => "#$subs[$_*2]", id => "jt_sel_$subs[$_*2]", $subs[$_*2+1][0];
        end;
      }
      li class => 'left';
       a href => '#all', id => 'jt_sel_all', 'All items';
      end;
     end 'ul';
    end 'div';
  }

  # form subs
  while(my($short, $parts) = (shift(@subs), shift(@subs))) {
    last if !$short || !$parts;
    my $name = shift @$parts;
    div class => 'mainbox', id => 'jt_box_'.$short;
     h1 $name;
     fieldset;
      legend $name;
      table class => 'formtable';
       $self->htmlFormPart($options->{frm}, $_) for @$parts;
      end;
     end;
    end 'div';
  }

  # db mod / edit summary / submit button
  if(!$options->{nosubmit}) {
    div class => 'mainbox';
     fieldset class => 'submit';
      if($options->{editsum}) {
        # hidden / locked checkbox
        if($self->authCan('dbmod')) {
          input type => 'checkbox', name => 'ihid', id => 'ihid', value => 1,
            tabindex => 10, $options->{frm}{ihid} ? (checked => 'checked') : ();
          label for => 'ihid', 'Deleted';
          input type => 'checkbox', name => 'ilock', id => 'ilock', value => 1,
            tabindex => 10, $options->{frm}{ilock} ? (checked => 'checked') : ();
          label for => 'ilock', 'Locked';
          br; txt 'Note: edit summary of the last edit should indicate the reason for the deletion.'; br;
        }

        # edit summary
        h2;
         txt 'Edit summary';
         b class => 'standout', ' (English please!)';
        end;
        textarea name => 'editsum', id => 'editsum', rows => 4, cols => 50, tabindex => 10, $options->{frm}{editsum}||'';
        br;
      }
      if(!$options->{continue}) {
        input type => 'submit', value => 'Submit', class => 'submit', tabindex => 10;
      } else {
        input type => 'submit', value => 'Continue', class => 'submit', tabindex => 10;
        input type => 'submit', name => 'continue_ign', value => 'Continue and ignore duplicates',
          class => 'submit', style => 'width: auto', tabindex => 10 if $options->{continue} == 2;
      }
      input type => 'submit', value => 'Preview', id => 'preview', name => 'preview', class => 'submit', tabindex => 10 if $options->{preview};
     end;
    end 'div';
  }

  end 'form';
}


1;

