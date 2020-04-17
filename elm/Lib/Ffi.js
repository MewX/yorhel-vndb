window.elmFfi_innerHtml = function(wrap,call) { // \s -> _VirtualDom_property('innerHTML', _Json_wrap(s))
    return function(s) {
        return {
            $: 'a2',
            n: 'innerHTML',
            o: wrap(s)
        }
    }
};

window.elmFfi_elemCall = function(wrap,call) { // _Browser_call
    return call
};

window.elmFfi_fmtFloat = function(wrap,call) {
    return function(val) {
        return function(prec) {
            return val.toLocaleString('en-US', { minimumFractionDigits: prec, maximumFractionDigits: prec });
        }
    }
};

var urlStatic = document.querySelector('link[rel=stylesheet]').href.replace(/^(https?:\/\/[^/]+)\/.*$/, '$1');
window.elmFfi_urlStatic = function(wrap,call) {
    return urlStatic
};
