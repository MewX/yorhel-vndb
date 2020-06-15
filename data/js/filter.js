/* Filter box definition:
 * [ <title>,
 *   [ <category_name>,
 *     [ <fieldcode>, <fieldname>, <fieldcontents>, <fieldreadfunc>, <fieldwritefunc>, <fieldshowfunc> ], ..
 *   ], ..
 * ]
 * Where:
 *  <title>           human-readable title of the filter box
 *  <category_name>   human-readable name of the category. ignored if there's only one category
 *  <fieldcode>       code of this field, refers to the <field> in the filter format. Empty string for just a <tr>
 *  <fieldname>       human-readanle name of the field. Empty to not display a label. Space for always-enabled items (without checkbox)
 *  <fieldcontents>   tag() object, or an array of tag() objects
 *  <fieldreadfunc>   function reference. argument: <fieldcontents>; must return data to be used in the filter format
 *  <fieldwritefunc>  function reference, argument: <fieldcontents>, data from filter format; must update the contents with the passed data
 *  <fieldshowfunc>   function reference, argument: <fieldcontents>, called when the field is displayed
 *
 * Filter string format:
 *  <field>-<value1>~<value2>.<field2>-<value>.<field3>-<value1>~<value2>
 * Where:
 *  <field> = [a-z0-9]+
 *  <value> = [a-zA-Z0-9_]+ and any UTF-8 characters not in the ASCII range
 * Escaping of the <value>:
 *  "_<two-number-code>"
 * Where <two-number-code> is the decimal index to the following array:
 *  _ <space> ! " # $ % & ' ( ) * + , - . / : ; < = > ? @ [ \ ]  ^ ` { | } ~
 * For boolean fields, the <value> is either 0 or 1.
 */

var fil_escape = "_ !\"#$%&'()*+,-./:;<=>?@[\\]^`{|}~".split('');
var fil_objs = [];

var resolutions = [
    ["unknown","Unknown / console / handheld"],
    ["nonstandard","Non-standard"],
    ["4:3",["640x480","640x480"],["800x600","800x600"],["1024x768","1024x768"],["1280x960","1280x960"],["1600x1200","1600x1200"]],
    ["widescreen",["640x400","640x400"],["960x600","960x600"],["960x640","960x640"],["1024x576","1024x576"],["1024x600","1024x600"],["1024x640","1024x640"],["1280x720","1280x720"],["1280x800","1280x800"],["1366x768","1366x768"],["1600x900","1600x900"],["1920x1080","1920x1080"]]
];

function getObj(obj) {
    while(!obj.fil_fields)
        obj = obj.parentNode;
    return obj;
}


function filLoad(lnk, serobj) {
  var type = lnk.href.match(/#r$/) ? 'r' : lnk.href.match(/#c$/) ? 'c' : lnk.href.match(/#s$/) ? 's' : 'v';
  var l = {r: filReleases, c: filChars, s: filStaff, v: filVN}[type]();

  var fields = {};
  var cats = [];
  var p = tag('p', {'class':'browseopts'});
  var c = tag('div', null);
  var idx = 0;
  for(var i=1; i<l.length; i++) {
    if(!l[i])
      continue;

    // category link
    var a = tag('a', { href: '#', onclick: selectCat, fil_onshow:[] }, l[i][0]);
    cats.push(a);
    p.appendChild(a);
    p.appendChild(tag(' '));

    // category contents
    var t = tag('table', {'class':'formtable hidden', fil_a: a}, null);
    a.fil_t = t;
    for(var j=1; j<l[i].length; j++) {
      var fd = l[i][j];
      var lab = typeof fd[1] == 'object' ? fd[1][0] : fd[1];
      var name = 'fil_check_'+type+'_'+fd[0];
      var f = tag('tr', {'class':'newfield', fil_code: fd[0], fil_readfunc: fd[3], fil_writefunc: fd[4]},
        // Checkbox
        fd[0] ? tag('td', {'class':'check'},
            tag('input', {type:'checkbox', id:name, name:name, 'class': 'enabled_check'+(fd[1]==' '?' hidden':''), onclick: selectField }))
          : tag('td', null),
        // Label
        fd[1] ? tag('td', {'class':'label'},
          tag('label', {'for':name}, lab),
          typeof fd[1] == 'object' ? tag('b', fd[1][1]) : null
        ) : null,
        // Contents
        tag('td', {'class':'cont' }, fd[2]));
      if(fd[0])
        fields[fd[0]] = f;
      if(fd[5])
        a.fil_onshow.push([ fd[5], fd[2] ]);
      t.appendChild(f);
    }
    c.appendChild(t);
    idx++;
  }

  var savenote = tag('p', {'class':'hidden'}, '')
  var obj = tag('div', {
      'class': 'fil_div hidden',
      fil_fields: fields,
      fil_cats: cats,
      fil_savenote: savenote,
      fil_serobj: serobj,
      fil_lnk: lnk,
      fil_type: type
    },
    tag('a', {href:'#', onclick:show, 'class':'close'}, 'close'),
    tag('h3', l[0]),
    p,
    tag('b', {'class':'ruler'}, null),
    c,
    tag('b', {'class':'ruler'}, null),
    tag('input', {type:'button', 'class':'submit', value: 'Apply', onclick:function () {
      var f = serobj;
      while(f.nodeName.toLowerCase() != 'form')
        f = f.parentNode;
      f.submit();
    }}),
    tag('input', {type:'button', 'class':'submit', value: 'Reset', onclick:function () { serobj.value = ''; deSerialize(obj) } }),
    byId('pref_code') && lnk.id == 'filselect' ? tag('input', {type:'button', 'class':'submit', value: 'Save as default', onclick:saveDefault }) : null,
    savenote
  );
  lnk.fil_obj = obj;
  lnk.onclick = show;

  addBody(obj);
  fil_objs.push(obj);
  deSerialize(obj);
  selectCat(obj.fil_cats[0]);
}


function saveDefault() {
  var but = this;
  var obj = getObj(this);
  var note = obj.fil_savenote;
  setText(note, 'Loading...');
  but.enabled = false;
  setClass(note, 'hidden', false);
  var type = obj.fil_type == 'r' ? 'release' : 'vn';
  ajax('/xml/prefs.xml?formcode='+byId('pref_code').title+';key=filter_'+type+';value='+obj.fil_serobj.value, function (hr) {
    setText(note, 'Your saved filters will be applied automatically to several other parts of the site as well, such as the homepage.'+
      ' To change these filters, come back to this page and use the "Save as default" button again.'+
      ' To remove your saved filters, hit "Reset" and then save.');
    but.enable = true;
  });
}


function selectCat(n) {
  var lnk = n.fil_onshow ? n : this;
  var obj = getObj(lnk);
  setClass(obj.fil_savenote, 'hidden', true);
  for(var i=0; i<obj.fil_cats.length; i++) {
    var n = obj.fil_cats[i];
    setClass(n, 'optselected', n == lnk);
    setClass(n.fil_t, 'hidden', n != lnk);
  }
  for(var i=0; i<lnk.fil_onshow.length; i++)
    lnk.fil_onshow[i][0](lnk.fil_onshow[i][1]);
  return false
}


function selectField(f) {
  if(!f.parentNode)
      f = this;
  setClass(getObj(f).fil_savenote, 'hidden', true);

  // update checkbox and label
  var o = f;
  while(o.nodeName.toLowerCase() != 'tr')
    o = o.parentNode;
  var c = byClass(o, 'enabled_check')[0];
  if(c != f)
    c.checked = true;
  if(hasClass(c, 'hidden')) // When there's no label (e.g. tagspoil selector)
    c.checked = true;
  var l = byName(o, 'label')[0];
  if(l)
    setClass(l, 'active', c.checked);

  // update category link
  while(o.nodeName.toLowerCase() != 'table')
    o = o.parentNode;
  var l = byName(o, 'tr');
  var n=0;
  for(var i=0; i<l.length; i++) {
    var ch = byClass(l[i], 'enabled_check')[0];
    if(ch && !hasClass(ch, 'hidden') && ch.checked)
      n++;
  }
  setClass(o.fil_a, 'active', n>0);

  // serialize
  serialize(getObj(o));
  return true;
}


function escapeVal(val) {
  var r = [];
  for(var h=0; h<val.length; h++) {
    var vs = (''+val[h]).split('');
    r[h] = '';

    // this isn't a very fast escaping method, blame JavaScript for inflexible search/replace support
    for(var i=0; i<vs.length; i++) {
      for(var j=0; j<fil_escape.length; j++)
        if(vs[i] == fil_escape[j])
          break;
      r[h] += j == fil_escape.length ? vs[i] : '_'+(j<10?'0'+j:j);
    }
  }

  return r[0] == '' ? '' : r.join('~');
}


function serialize(obj) {
  if(!obj.fil_fields)
    obj = getObj(this);
  var num = 0;
  var values = {};

  for(var f in obj.fil_fields) {
    var fo = obj.fil_fields[f];
    var ch = byClass(fo, 'enabled_check')[0];
    if(!ch || !ch.checked)
      continue;
    if(!hasClass(ch, 'hidden'))
      num++;

    var v = escapeVal(fo.fil_readfunc(byClass(fo, 'cont')[0].childNodes[0]));
    if(v != '')
      values[fo.fil_code] = v;
  }

  var l = [];
  for(var f in values)
    l.push(f+'-'+values[f]);

  obj.fil_serobj.value = l.join('.');
  setText(byName(obj.fil_lnk, 'i')[1], num > 0 ? ' ('+num+')' : '');
}


function deSerialize(obj) {
  var d = obj.fil_serobj.value;
  var fs = d.split('.');

  var f = {};
  for(var i=0; i<fs.length; i++) {
    var v = fs[i].split('-');
    if(obj.fil_fields[v[0]])
      f[v[0]] = v[1];
  }

  for(var fn in obj.fil_fields)
    if(!f[fn])
      f[fn] = '';
  for(var fn in f) {
    var c = byClass(obj.fil_fields[fn], 'enabled_check')[0];
    if(!c)
      continue;
    c.checked = f[fn] != '';

    var v = f[fn].split('~');
    for(var i=0; i<v.length; i++)
      v[i] = v[i].replace(/_([0-9]{2})/g, function (a, e) { return fil_escape[Math.floor(e)] });

    obj.fil_fields[fn].fil_writefunc(byClass(obj.fil_fields[fn], 'cont')[0].childNodes[0], v);
    // not very efficient: selectField() does a lot of things that can be
    //  batched after all fields have been updated, and in some cases the
    //  writefunc() triggers the same selectField() as well
    selectField(c);
  }
}


function show() {
  var obj = this.fil_obj || getObj(this);

  // Hide other filter objects
  for(var i=0; i<fil_objs.length; i++)
    if(fil_objs[i] != obj) {
      setClass(fil_objs[i], 'hidden', true);
      setText(byName(fil_objs[i].fil_lnk, 'i')[0], collapsed_icon);
    }

  var hid = !hasClass(obj, 'hidden');
  setClass(obj, 'hidden', hid);
  setText(byName(obj.fil_lnk, 'i')[0], hid ? collapsed_icon : expanded_icon);
  setClass(obj.fil_savenote, 'hidden', true);

  var o = obj.fil_lnk;
  ddx = ddy = 0;
  do {
    ddx += o.offsetLeft;
    ddy += o.offsetTop;
  } while(o = o.offsetParent);
  ddy += obj.fil_lnk.offsetHeight+2;
  ddx += (obj.fil_lnk.offsetWidth-obj.offsetWidth)/2;
  obj.style.left = ddx+'px';
  obj.style.top = ddy+'px';

  return false;
}


var curSlider = null;
function filFSlider(c, n, min, max, def, unit, ser, deser) {
  // min/max/def/fil_val are in serialized form (i.e. a "value")
  if(!ser)   ser   = function(v) { return v }; // integer -> value
  if(!deser) deser = function(v) { return parseInt(v) }; // value -> integer

  min = deser(min);
  max = deser(max);
  var bw = 200; var pw = 1;  // slidebar width and pointer width
  var s = tag('p', {fil_val:def, 'class':'slider'});
  var b = tag('div', {style:'width:'+(bw-2)+'px;', s:s});
  var p = tag('div', {style:'width:'+pw+'px;', s:s});
  var v = tag('span', def+' '+unit);
  s.appendChild(b);
  b.appendChild(p);
  s.appendChild(v);

  var set = function (e, v) {
    var w = bw-pw-6;
    var s,x;

    if(v) {
      s = e;
      x = deser(v[0] == '' ? def : v[0]);
      x = (x-min)*w/(max-min);
    } else {
      s = curSlider;
      if(!e) e = window.event;
      x = (!e) ? (deser(def)-min)*w/(max-min)
        : (e.pageX || e.clientX + document.body.scrollLeft - document.body.clientLeft)-5;
      var o = s.childNodes[0];
      while(o.offsetParent) {
        x -= o.offsetLeft;
        o = o.offsetParent;
      }
    }

    if(x<0) x = 0; if(x>w) x = w;
    s.fil_val = ser(min + Math.floor(x*(max-min)/w));
    s.childNodes[1].innerHTML = s.fil_val+' '+unit;
    s.childNodes[0].childNodes[0].style.left = x+'px';
    return false;
  }

  b.onmousedown = p.onmousedown = function (e) {
    curSlider = this.s;
    if(!curSlider.oldmousemove) curSlider.oldmousemove = document.onmousemove;
    if(!curSlider.oldmouseup) curSlider.oldmouseup = document.onmouseup;
    document.onmouseup = function () {
      document.onmousemove = curSlider.oldmousemove;
      curSlider.oldmousemove = null;
      document.onmouseup = curSlider.oldmouseup;
      curSlider.oldmouseup = null;
      selectField(curSlider);
      return false;
    }
    document.onmousemove = set;
    return set(e);
  }

  return [c, n, s, function (c) { return [ c.fil_val ]; }, set ];
}

function filFSelect(c, n, lines, opts) {
  var s = tag('select', {onfocus: selectField, onchange: serialize, multiple: lines > 1, size: lines});
  for(var i=0; i<opts.length; i++) {
    if(typeof opts[i][1] != 'object')
      s.appendChild(tag('option', {name: opts[i][0]}, opts[i][1]));
    else {
      var g = tag('optgroup', {label: opts[i][0]});
      for(var j=1; j<opts[i].length; j++)
        g.appendChild(tag('option', {name: opts[i][j][0]}, opts[i][j][1]));
      s.appendChild(g);
    }
  }
  return [ c, lines > 1 ? [ n, 'Boolean or, selecting more gives more results' ] : n, s,
    function (c) {
      var l = [];
      for(var i=0; i<c.options.length; i++)
        if(c.options[i].selected)
          l.push(c.options[i].name);
      return l;
    },
    function (c, f) {
      for(var i=0; i<c.options.length; i++) {
        for(var j=0; j<f.length; j++)
          if(c.options[i].name+'' == f[j]+'') // beware of JS logic: 0 == '', but '0' != ''
            break;
        c.options[i].selected = j != f.length;
      }
    }
  ];
}

function filFInput(c, n) {
  return [ c, n,
    tag('input', {type: 'text', 'class': 'text', onfocus: selectField, onchange: serialize}),
    function (c) { return [c.value] },
    function (c, f) { c.value = f }
  ]
}

function filFEngine(c, n) {
  var input = tag('input', {type: 'text', 'class': 'text', onfocus: selectField, onchange: serialize});
  dsInit(input, '/xml/engines.xml?q=',
    function(item, tr) { tr.appendChild(tag('td', shorten(item.firstChild.nodeValue, 40))); },
    function(item, obj) { return item.firstChild.nodeValue; },
    function(o) { selectField(o) }
  );
  return [ c, n, input,
    function (c) { return [c.value] },
    function (c, f) { c.value = f }
  ]
}


function filFOptions(c, n, opts) {
  var p = tag('p', {'class':'opts', fil_val:opts[0][0]});
  var sel = function (e) {
    var o = typeof e == 'string' ? e : this.fil_n;
    var l = byName(p, 'a');
    for(var i=0; i<l.length; i++)
      setClass(l[i], 'tsel', l[i].fil_n+'' == o+'');
    p.fil_val = o;
    if(typeof e != 'string')
      selectField(p);
    return false
  };
  for(var i=0; i<opts.length; i++) {
    p.appendChild(tag('a', {href:'#', fil_n: opts[i][0], onclick:sel}, opts[i][1]));
    if(i<opts.length-1)
      p.appendChild(tag('b', '|'));
  }
  return [ c, n, p,
    function (c) { return [ c.fil_val ] },
    function (c, v) { sel(v[0]) }
  ];
}


// fieldcode  -> See <fieldcode> in filter definitions
// fieldname  -> See <fieldname> in filter definitions
// src        -> The API URL where to get items, must work with dropdownsearch.js and support appending ';q=', ';id=' and ';r=' to it.
// fmtlist    -> Called with item id + XML data, should return an inline element to inject into the list view.
function filFDList(fieldcode, fieldname, src, fmtds, fmtlist) {
  var visible = false;
  var addel = function(ul, id, data) {
    ul.appendChild(
      tag('li', { fil_id: id },
        data ? fmtlist(id, data) : null,
        ' (', tag('a', {href:'#',
          onclick:function () {
            // a -> li -> ul -> div
            var ul = this.parentNode.parentNode;
            ul.removeChild(this.parentNode);
            selectField(ul.parentNode);
            return false
          }
        }, 'remove'), ')'
    ));
  }
  var fetch = function(c)   {
    var v = c.fil_val;
    var ul = byName(c, 'ul')[0];
    var txt = byName(c, 'input')[0];
    if(v == null)
      return;
    if(!v[0]) {
      setText(ul, '');
      txt.disabled = false;
      txt.value = '';
      return;
    }
    if(!visible)
      setText(ul, '');
    var q = [];
    for(var i=0; i<v.length; i++) {
      q.push('id='+v[i]);
      if(!visible)
        addel(ul, v[i]);
    }
    txt.value = 'Loading...';
    txt.disabled = true;
    if(visible)
      ajax(src+';r=50;'+q.join(';'), function (hr) {
        var items = hr.responseXML.getElementsByTagName('item');
        setText(ul, '');
        for(var i=0; i<items.length; i++)
          addel(ul, items[i].getAttribute('id'), items[i]);
        txt.value = '';
        txt.disabled = false;
        c.fil_val = null;
      }, 1);
  };
  var input = tag('input', {type:'text', 'class':'text', style:'width:300px', onfocus:selectField});
  var list = tag('ul', null);
  dsInit(input, src+';q=', fmtds,
    function(item, obj) {
      if(byName(obj.parentNode, 'li').length >= 50)
        alert('Too many items selected');
      else {
        obj.parentNode.fil_val = null;
        addel(byName(obj.parentNode, 'ul')[0], item.getAttribute('id'), item);
        selectField(obj);
      }
      return '';
    },
    function(o) { selectField(o) }
  );

  return [
    fieldcode, fieldname, tag('div', list, input),
    function(c) {
      var v = []; var l = byName(c, 'li');
      for(var i=0; i<l.length; i++)
        v.push(l[i].fil_id);
      return v;
    },
    function(c,v) { c.fil_val = v; fetch(c) },
    function(c) { visible = true; fetch(c); }
  ];
}

function filFTagInput(code, name) {
  return filFDList(code, name, '/xml/tags.xml?searchable=1',
    function(item, tr) {
      tr.appendChild(tag('td', shorten(item.firstChild.nodeValue, 40)));
    },
    function(id, item) {
      return tag('span', tag('a', {href:'/g'+id}, item.firstChild.nodeValue||'g'+id))
    }
  )
}

function filFTraitInput(code, name) {
  return filFDList(code, name, '/xml/traits.xml?searchable=1',
    function(item, tr) {
      var g = item.getAttribute('groupname');
      tr.appendChild(tag('td',
        g ? tag('b', {'class':'grayedout'}, g+' / ') : null,
        shorten(item.firstChild.nodeValue, 40)
      ));
    },
    function(id, item) {
      var g = item.getAttribute('groupname');
      return tag('span',
        g ? tag('b', {'class':'grayedout'}, g+' / ') : null,
        tag('a', {href:'/i'+id}, item.firstChild.nodeValue||'i'+id)
      )
    }
  )
}

function filFProducerInput(code, name) {
  return filFDList(code, name, '/xml/producers.xml?',
    function(item, tr) {
      tr.appendChild(tag('td', shorten(item.firstChild.nodeValue, 40)));
    },
    function(id, item) {
      return tag('span', tag('a', {href:'/p'+id}, item.firstChild.nodeValue||'p'+id))
    }
  )
}

function filFStaffInput(code, name) {
  return filFDList(code, name, '/xml/staff.xml?staffid=1',
    function(item, tr) {
      tr.appendChild(tag('td', shorten(item.firstChild.nodeValue, 40)));
    },
    function(id, item) {
      return tag('span', tag('a', {href:'/s'+id}, item.firstChild.nodeValue||'s'+id))
    }
  )
}


function filChars() {
  var ontraitpage = location.pathname.indexOf('/i') == 0;

  var cup_ser = function(v) { return VARS.cup_size[parseInt(v)] };
  var cup_deser = function(v) {
    for(var i=0; i<VARS.cup_size.length; i++)
      if(VARS.cup_size[i] == v)
        return i;
    return 0;
  };

  return [
    'Character filters',
    [ 'General',
      filFSelect('gender',     'Gender',     4, VARS.genders),
      filFSelect('bloodt',     'Blood type', 5, VARS.blood_types),
      '',
      filFSlider('bust_min',   'Bust min',  20, 120, 40,  'cm'),
      filFSlider('bust_max',   'Bust max',  20, 120, 100, 'cm'),
      filFSlider('waist_min',  'Waist min', 20, 120, 40,  'cm'),
      filFSlider('waist_max',  'Waist max', 20, 120, 100, 'cm'),
      filFSlider('hip_min',    'Hips min',  20, 120, 40,  'cm'),
      filFSlider('hip_max',    'Hips max',  20, 120, 100, 'cm'),
      '',
      filFSlider('height_min', 'Height min', 0, 300, 60,  'cm'),
      filFSlider('height_max', 'Height max', 0, 300, 240, 'cm'),
      filFSlider('weight_min', 'Weight min', 0, 400, 80,  'kg'),
      filFSlider('weight_max', 'Weight max', 0, 400, 320, 'kg'),
      filFSlider('cup_min',    'Cup size min', 'AAA', 'Z', 'AAA', '', cup_ser, cup_deser),
      filFSlider('cup_max',    'Cup size max', 'AAA', 'Z', 'E',   '', cup_ser, cup_deser)
    ],
    ontraitpage ? [ 'Traits',
      [ '', ' ', tag('Additional trait filters are not available on this page. Use the character browser instead (available from the main menu -> characters).') ],
    ] : [ 'Traits',
      [ '', ' ', tag('Boolean and, selecting more gives less results') ],
      filFTraitInput('trait_inc', 'Traits to include'),
      filFTraitInput('trait_exc', 'Traits to exclude'),
      filFOptions('tagspoil', ' ', [[0, 'Hide spoilers'],[1, 'Show minor spoilers'],[2, 'Spoil me!']]),
    ],
    [ 'Roles', filFSelect('role', 'Roles', 4, VARS.char_roles) ],
    [ 'Seiyuu',
      [ '',       ' ',                     tag('Boolean or, selecting more gives more results') ],
      filFStaffInput('va_inc', 'Seiyuu to include'),
      filFStaffInput('va_exc', 'Seiyuu to exclude')
    ],
  ];
}

function filReleases() {
  var plat = VARS.platforms;
  plat.splice(0, 0, [ 'unk', 'Unknown' ]);
  var med = VARS.media;
  med.splice(0, 0, [ 'unk', 'Unknown' ]);
  return [
    'Release filters',
    [ 'General',
      filFOptions('type',     'Release type',    VARS.release_types),
      filFOptions('patch',    'Patch status',    [ [1, 'Patch'], [0, 'Standalone'] ]),
      filFOptions('freeware', 'Freeware',        [ [1, 'Only freeware'], [0, 'Only non-free releases'] ]),
      filFOptions('doujin',   'Doujin',          [ [1, 'Only doujin releases'], [0, 'Only commercial releases'] ]),
      filFOptions('uncensored','Censoring',      [ [1, 'Only uncensored releases'], [0, 'Censored or non-erotic releases'] ]),
      [ 'date_after',  'Released after',  dateLoad(null, selectField), function (c) { return [c.date_val] }, function(o,v) { o.dateSet(v) } ],
      [ 'date_before', 'Released before', dateLoad(null, selectField), function (c) { return [c.date_val] }, function(o,v) { o.dateSet(v) } ],
      filFOptions('released', 'Release date',    [ [1, 'Past (already released)'], [0, 'Future (to be released)'] ])
    ],
    [ 'Age rating',           filFSelect('minage',     'Age rating',        15, VARS.age_ratings) ],
    [ 'Language',             filFSelect('lang',       'Language',          20, VARS.languages) ],
    byId('rfilselect') ? null :
      [ 'Original language',    filFSelect('olang',    'Original language', 20, VARS.languages) ],
    [ 'Screen resolution',    filFSelect('resolution', 'Screen resolution', 15, resolutions) ],
    [ 'Platform',             filFSelect('plat',       'Platform',          20, plat) ],
    [ 'Producer',
      [ '',       ' ',                     tag('Boolean or, selecting more gives more results') ],
      filFProducerInput('prod_inc', 'Producers to include'),
      filFProducerInput('prod_exc', 'Producers to exclude')
    ],
    [ 'Misc',
      filFSelect('med',       'Medium',         10, med),
      filFSelect('voiced',    'Voiced',          5, VARS.voiced),
      filFSelect('ani_story', 'Story animation', 5, VARS.animated),
      filFSelect('ani_ero',   'Ero animation',   5, VARS.animated),
      filFEngine('engine',    'Engine')
    ]
  ];
}

function filVN() {
  var ontagpage = location.pathname.indexOf('/v/') < 0;

  return [
    'Visual Novel Filters',
    [ 'General',
      filFSelect( 'length', 'Length', 6, VARS.vn_lengths),
      filFOptions('hasani', 'Anime',       [[1, 'Has anime'],     [0, 'Does not have anime']]),
      filFOptions('hasshot','Screenshots', [[1, 'Has screenshot'],[0, 'Does not have a screenshot']]),
      [ 'date_after',  'Released after',  dateLoad(null, selectField), function (c) { return [c.date_val] }, function(o,v) { o.dateSet(v) } ],
      [ 'date_before', 'Released before', dateLoad(null, selectField), function (c) { return [c.date_val] }, function(o,v) { o.dateSet(v) } ],
      filFOptions('released', 'Release date',    [ [1, 'Past (already released)'], [0, 'Future (to be released)'] ])
    ],
    ontagpage ? [ 'Tags',
      [ '', ' ', tag('Additional tag filters are not available on this page. Use the visual novel browser instead (available from the main menu -> visual novels).') ],
    ] : [ 'Tags',
      [ '',       ' ',                     tag('Boolean and, selecting more gives less results') ],
      [ '',       ' ', byId('pref_code') ? tag('These filters are ignored on tag pages (when set as default).') : null ],
      filFTagInput('tag_inc', 'Tags to include'),
      filFTagInput('tag_exc', 'Tags to exclude'),
      filFOptions('tagspoil', ' ', [[0, 'Hide spoilers'],[1, 'Show minor spoilers'],[2, 'Spoil me!']])
    ],
    [ 'Language',          filFSelect('lang', 'Language',          20, VARS.languages) ],
    [ 'Original language', filFSelect('olang','Original language', 20, VARS.languages) ],
    [ 'Platform',          filFSelect('plat', 'Platform',          20, VARS.platforms) ],
    [ 'Staff',
      [ '',       ' ',                     tag('Boolean or, selecting more gives more results') ],
      filFStaffInput('staff_inc', 'Staff to include'),
      filFStaffInput('staff_exc', 'Staff to exclude')
    ],
    !byId('pref_code') ? null : [
      'My lists',
      filFOptions('ul_notblack', 'Blacklist', [[1, 'Exclude VNs on my blacklist']]),
      filFOptions('ul_onwish',   'Wishlist',  [[0, 'Not on my wishlist'],[1, 'On my wishlist']]),
      filFOptions('ul_voted',    'Voted',     [[0, 'Not voted on'], [1, 'Voted on' ]]),
      filFOptions('ul_onlist',   'VN list',   [[0, 'Not on my VN list'],[1, 'On my VN list']])
    ],
  ];
}

function filStaff() {
  var gend = VARS.genders.slice(0, 3);

  // Insert seiyuu into the list of roles, before the "staff" role.
  var roles = VARS.credit_type;
  roles.splice(-1, 0, ['seiyuu', 'Voice actor']);

  return [
    'Staff filters',
    [ 'General',
      filFOptions('truename', 'Names', [[1, 'Primary names only'],[0, 'Include aliases']]),
      filFSelect('role', 'Roles', roles.length, roles),
      '',
      filFSelect('gender', 'Gender', gend.length, gend),
    ],
    [ 'Language',   filFSelect('lang',       'Language',   20, VARS.languages) ],
  ];
}

if(byId('filselect'))
  filLoad(byId('filselect'), byId('fil'));
if(byId('rfilselect'))
  filLoad(byId('rfilselect'), byId('rfil'));
if(byId('cfilselect'))
  filLoad(byId('cfilselect'), byId('cfil'));
