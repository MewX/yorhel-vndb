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


/* Find all divs with a data-elm-module and embed the given Elm module in the div */
document.querySelectorAll('div[data-elm-module]').forEach(function(el) {
    var mod = el.getAttribute('data-elm-module').split('.').reduce(function(p, c) { return p[c] }, window.Elm);
    var flags = el.getAttribute('data-elm-flags');
    if(flags)
        mod.init({ node: el, flags: JSON.parse(flags)});
    else
        mod.init({ node: el });
});
