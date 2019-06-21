var spoil, sexual, t;


// Fixes the commas between trait names and the hidden status of the entire row
function fixrow(c) {
  var l = byName(byName(c, 'td')[1], 'span');
  var first = 1;
  for(var i=0; i<l.length; i++)
    if(!hasClass(l[i], 'ishidden')) {
      first = 0;
      break;
    }
  setClass(c, 'hidden', first);
}


function restripe() {
  for(var i=0; i<t.length; i++) {
    var b = byName(t[i], 'tbody');
    if(!b.length)
      continue;
    setClass(t[i], 'stripe', false);
    var r = 1;
    var rows = byName(b[0], 'tr');
    for(var j=0; j<rows.length; j++) {
      if(hasClass(rows[j], 'traitrow'))
        fixrow(rows[j]);
      if(!hasClass(rows[j], 'nostripe') && !hasClass(rows[j], 'hidden'))
        setClass(rows[j], 'odd', r++&1);
    }
  }
}


function setall() {
  var k = byClass('charspoil');
  for(var i=0; i<k.length; i++)
    setClass(k[i], 'ishidden',
      !sexual && hasClass(k[i], 'sexual') ? true :
      hasClass(k[i], 'charspoil_0') ? false :
      hasClass(k[i], 'charspoil_-1') ? spoil > 1 :
      hasClass(k[i], 'charspoil_1') ? spoil < 1 : spoil < 2);

  if(k.length)
    restripe();
  return false;
}


function init() {
  var opsParent = byId('charops');
  if(!opsParent)
    return;

  t = byClass('table', 'stripe');

  // Spoiler level
  for(var i=0; i<3; i++) {
    var splChk = byClass(opsParent, 'radio_spoil' + i)[0];
    if(!splChk)
      continue;

    splChk.num = i;
    splChk.onchange = function() {
      spoil = this.num;
      return setall();
    };
    if(splChk.checked)
      spoil = i;
  };

  // Sexual toggle
  var sexChk = byClass(opsParent, 'sexual_check');
  if(sexChk.length) {
    sexChk = sexChk[0]

    sexChk.onchange = function() {
      sexual = !sexual;
      return setall();
    };
    sexual = sexChk.checked;
  }
  setall();
}


if(byId('charops'))
  init();
