// expand/collapse release listing (/p+)
(function(){
  var lnk = byId('expandprodrel');
  if(!lnk)
    return;
  function setexpand() {
    var exp = !(getCookie('prodrelexpand') == 1);
    setText(lnk, exp ? 'collapse' : 'expand');
    setClass(byId('prodrel'), 'collapse', !exp);
  };
  lnk.onclick = function () {
    setCookie('prodrelexpand', getCookie('prodrelexpand') == 1 ? 0 : 1);
    setexpand();
    return false;
  };
  setexpand();
})();


// search tabs
(function(){
  function click() {
    var str = byId('q').value;
    if(str.length > 1) {
      this.href = this.href.split('?')[0];
      if(this.href.indexOf('/g') >= 0 || this.href.indexOf('/i') >= 0)
        this.href += '/list';
      this.href += '?q=' + encodeURIComponent(str);
    }
    return true;
  };
  if(byId('searchtabs')) {
    var l = byName(byId('searchtabs'), 'a');
    for(var i=0; i<l.length; i++)
      l[i].onclick = click;
  }
})();


// external links dropdown for releases (/p+)
(function(){
  var l = byClass('rllinks');
  for(var i=0; i<l.length; i++) {
    var o = byName(l[i].parentNode, 'ul')[0];
    if(o) {
      l[i].links_ul = l[i].parentNode.removeChild(o);
      setClass(l[i].links_ul, 'hidden', false);
      ddInit(l[i], 'left', function(acr) {
        return acr.links_ul;
      });
      if(l[i].href.match(/#$/)) {
        l[i].onclick = function() { return false; };
      }
    }
  }
})();


// spam protection on all forms
setTimeout(function() {
  for(var i=1; i<document.forms.length; i++)
    document.forms[i].action = document.forms[i].action.replace(/\/nospam\?/,'');
}, 500);
