//order:8 - After all regular JS, as other files may modify pageVars or modules in the Elm.* namespace.

/* Add the X-CSRF-Token header to every POST request. Based on:
 * https://stackoverflow.com/questions/24196140/adding-x-csrf-token-header-globally-to-all-instances-of-xmlhttprequest/24196317#24196317
 */
(function() {
    var open = XMLHttpRequest.prototype.open,
        token = document.querySelector('meta[name=csrf-token]').content;

    XMLHttpRequest.prototype.open = function(method, url) {
        var ret = open.apply(this, arguments);
        this.dataUrl = url;
        if(method.toLowerCase() == 'post' && /^\//.test(url))
            this.setRequestHeader('X-CSRF-Token', token);
        return ret;
    };
})();


/* Load all Elm modules listed in the pageVars.elm array */
if(pageVars.elm) {
    //var t0 = performance.now();
    for(var i=0; i<pageVars.elm.length; i++) {
        var e = pageVars.elm[i];
        //if(e[0] != 'UList.DateEdit') continue;
        var mod = e[0].split('.').reduce(function(p, c) { return p[c] }, Elm);
        var node = document.getElementById('elm'+i);
        if(e.length > 1)
            mod.init({ node: node, flags: e[1] });
        else
            mod.init({ node: node });
    }
    //console.log("Elm modules initialized in " + (performance.now() - t0) + " milliseconds.");
}
