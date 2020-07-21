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


// spam protection on all forms
setTimeout(function() {
  for(var i=1; i<document.forms.length; i++)
    document.forms[i].action = document.forms[i].action.replace(/\/nospam\?/,'');
}, 500);
