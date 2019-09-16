/* Simple image viewer widget. Usage:
 *
 *   <a href="full_image.jpg" data-iv="{width}x{height}:{category}">..</a>
 *
 * Clicking on the above link will cause the image viewer to open
 * full_image.jpg. The {category} part can be empty or absent. If it is not
 * empty, next/previous links will show up to point to the other images within
 * the same category.
 *
 * ivInit() should be called when links with "data-iv" attributes are
 * dynamically added or removed from the DOM.
 */

// Cache of image categories and the list of associated link objects. Used to
// quickly generate the next/prev links.
var cats;

function init() {
  cats = {};
  var n = 0;
  var l = byName('a');
  for(var i=0;i<l.length;i++) {
    var o = l[i];
    if(o.getAttribute('data-iv') && o.id != 'ivprev' && o.id != 'ivnext') {
      n++;
      o.onclick = show;
      var cat = o.getAttribute('data-iv').split(':')[1];
      if(cat) {
        if(!cats[cat])
          cats[cat] = [];
        o.iv_i = cats[cat].length;
        cats[cat].push(o);
      }
    }
  }

  if(n && !byId('iv_view')) {
    addBody(tag('div', {id: 'iv_view','class':'hidden', onclick: function(ev) { ev.stopPropagation(); return true } },
      tag('b', {id:'ivimg'}, ''),
      tag('br', null),
      tag('a', {href:'#', id:'ivfull'}, ''),
      tag('a', {href:'#', onclick: close, id:'ivclose'}, 'close'),
      tag('a', {href:'#', onclick: show, id:'ivprev'}, '« previous'),
      tag('a', {href:'#', onclick: show, id:'ivnext'}, 'next »')
    ));
    addBody(tag('b', {id:'ivimgload','class':'hidden'}, 'Loading...'));
  }
}

// Find the next (dir=1) or previous (dir=-1) non-hidden link object for the category.
function findnav(cat, i, dir) {
  for(var j=i+dir; j>=0 && j<cats[cat].length; j+=dir)
    if(!hasClass(cats[cat][j], 'hidden') && cats[cat][j].offsetWidth > 0 && cats[cat][j].offsetHeight > 0)
      return cats[cat][j];
  return 0
}

// fix properties of the prev/next links
function fixnav(lnk, cat, i, dir) {
  var a = cat ? findnav(cat, i, dir) : 0;
  lnk.style.visibility = a ? 'visible' : 'hidden';
  lnk.href             = a ? a.href    : '#';
  lnk.iv_i             = a ? a.iv_i    : 0;
  lnk.setAttribute('data-iv', a ? a.getAttribute('data-iv') : '');
}

function show(ev) {
  var u = this.href;
  var opt = this.getAttribute('data-iv').split(':');
  var idx = this.iv_i;
  var view = byId('iv_view');
  var full = byId('ivfull');

  fixnav(byId('ivprev'), opt[1], idx, -1);
  fixnav(byId('ivnext'), opt[1], idx, 1);

  // calculate dimensions
  var w = Math.floor(opt[0].split('x')[0]);
  var h = Math.floor(opt[0].split('x')[1]);
  var ww = typeof(window.innerWidth) == 'number' ? window.innerWidth : document.documentElement.clientWidth;
  var wh = typeof(window.innerHeight) == 'number' ? window.innerHeight : document.documentElement.clientHeight;
  var st = typeof(window.pageYOffset) == 'number' ? window.pageYOffset : document.body && document.body.scrollTop ? document.body.scrollTop : document.documentElement.scrollTop;
  if(w+100 > ww || h+70 > wh) {
    full.href = u;
    setText(full, w+'x'+h);
    full.style.visibility = 'visible';
    if(w/h > ww/wh) { // width++
      h *= (ww-100)/w;
      w = ww-100;
    } else { // height++
      w *= (wh-70)/h;
      h = wh-70;
    }
  } else
    full.style.visibility = 'hidden';
  var dw = w;
  var dh = h+20;
  dw = dw < 200 ? 200 : dw;

  // update document
  setClass(view, 'hidden', false);
  setContent(byId('ivimg'), tag('img', {src:u, onclick:close,
    onload: function() { setClass(byId('ivimgload'), 'hidden', true); },
    style: 'width: '+w+'px; height: '+h+'px'
  }));
  view.style.width = dw+'px';
  view.style.height = dh+'px';
  view.style.left = ((ww - dw) / 2 - 10)+'px';
  view.style.top = ((wh - dh) / 2 + st - 20)+'px';
  byId('ivimgload').style.left = ((ww - 100) / 2 - 10)+'px';
  byId('ivimgload').style.top = ((wh - 20) / 2 + st)+'px';
  setClass(byId('ivimgload'), 'hidden', false);

  document.onclick = close;
  // Capture left/right arrow keys
  document.onkeydown = function(e) {
    if(e.keyCode == 37 && byId('ivprev').style.visibility == 'visible') {
      byId('ivprev').click();
    }
    if(e.keyCode == 39 && byId('ivnext').style.visibility == 'visible') {
      byId('ivnext').click();
    }
  };
  ev.stopPropagation();
  return false;
}

function close() {
  document.onclick = null;
  document.onkeydown = null;
  setClass(byId('iv_view'), 'hidden', true);
  setClass(byId('ivimgload'), 'hidden', true);
  setText(byId('ivimg'), '');
  return false;
}

window.ivInit = init;
init();
