//order:0 - Must be loaded before anything else.

/* classList.toggle() */
(function() {
    var historic = DOMTokenList.prototype.toggle;
    DOMTokenList.prototype.toggle = function(token, force) {
        if(arguments.length > 0 && this.contains(token) === force) {
            return force;
        }
        return historic.call(this, token);
    };
})();


/* Element.matches() and Element.closest() */
if(!Element.prototype.matches)
    Element.prototype.matches = Element.prototype.msMatchesSelector || Element.prototype.webkitMatchesSelector;
if(!Element.prototype.closest)
    Element.prototype.closest = function(s) {
        var el = this;
        if(!document.documentElement.contains(el)) return null;
        do {
            if(el.matches(s)) return el;
            el = el.parentElement || el.parentNode;
        } while(el !== null && el.nodeType === 1);
        return null;
    };


/* NodeList.forEach */
if(window.NodeList && !NodeList.prototype.forEach) {
    NodeList.prototype.forEach = Array.prototype.forEach;
}
