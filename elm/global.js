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


/* "checkall" checkbox, usage:
 *
 *    <input type="checkbox" class="checkall" name="$somename">
 *
 *  Checking that will synchronize all other checkboxes with name="$somename".
 */
document.querySelectorAll('input[type=checkbox].checkall').forEach(function(el) {
    el.onclick = function() {
        document.querySelectorAll('input[type=checkbox][name="'+el.name+'"]').forEach(function(el2) {
            if(!el2.classList.contains('hidden')) {
                if(el2.checked != el.checked)
                    el2.click();
            }
        });
    };
});


/* "checkhidden" checkbox, usage:
 *
 *    <input type="checkbox" class="checkhidden" value="$somename">
 *
 * Checking that will toggle the 'hidden' class of all elements with the "$somename" class.
 */
document.querySelectorAll('input[type=checkbox].checkhidden').forEach(function(el) {
    el.onclick = function() {
        document.querySelectorAll('.'+el.value).forEach(function(el2) {
            el2.classList.toggle('hidden', !el.checked);
        });
    };
});
