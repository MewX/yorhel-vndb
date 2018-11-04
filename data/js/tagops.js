var l, lim, spoil = 0, cats = {};

function init() {
  var i;
  l = byName(byId('tagops'), 'input');

  // Categories
  for(i=0; i<3; i++) {
    l[i].tagops_cat = l[i].id.substr(l[i].id.indexOf('cat')+4);
    l[i].onchange = function() { cats[this.tagops_cat] = !cats[this.tagops_cat]; return set(); };
    cats[l[i].tagops_cat] = l[i].checked;
  }

  // Spoiler level
  for(i=3; i<6; i++) {
    l[i].tagops_spoil = i-3;
    l[i].onchange = function() { spoil = this.tagops_spoil; return set(); };
    if(l[i].checked)
      spoil = i-3;
  }

  // Summary / all
  for(i=6; i<8; i++) {
    l[i].tagops_lim = i == 6;
    l[i].onchange = function() { lim = this.tagops_lim; return set(); };
    if(l[i].checked)
      lim = i == 6;
  }

  set();
}


function set() {
  var i;

  // update tag visibility
  var t = byName(byId('vntags'), 'span');

  var n = 0;
  for(i=0; i<t.length; i++) {
    var v = n < (lim ? 15 : 999);
    for(var j=0; j<3; j++)
      if(hasClass(t[i], 'tagspl'+j))
        v = v && j <= spoil;
    for(var c in cats)
      if(hasClass(t[i], 'cat_'+c))
        v = v && cats[c];
    setClass(t[i], 'hidden', !v);
    n += v?1:0;
  }

  return false;
}


if(byId('tagops'))
  init();
