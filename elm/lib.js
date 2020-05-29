//order:0 - Before anything else that may use these functions.

/* Load global page-wide variables from <script id="pagevars">...</script> and store them into window.pageVars */
var e = document.getElementById('pagevars');
window.pageVars = e ? JSON.parse(e.innerHTML) : {};


// Utlity function to wrap the init() function of an Elm module.
window.wrap_elm_init = function(mod, newinit) {
    mod = mod.split('.').reduce(function(p, c) { return p ? p[c] : null }, window.Elm);
    if(mod) {
        var oldinit = mod.init;
        mod.init = function(opt) { newinit(oldinit, opt) };
    }
};
